import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/image_object_service.dart';
import '../data/object_store.dart';
import '../data/system_object_store.dart';
import '../domain/object_model.dart';

/// Fail-closed boundary for deleting a canonical Image that is still mapped to
/// legacy Photo compatibility data.
class LegacyPhotoImageDeletionSafetyException implements Exception {
  const LegacyPhotoImageDeletionSafetyException();

  @override
  String toString() => 'この画像の従来データとの対応を安全に確認できないため削除できません。';
}

/// Resolves and removes only the exact legacy Photo row represented by one
/// canonical Image deletion.
///
/// This service deliberately does not delete the canonical Object or physical
/// file. The caller keeps Relation-safe Object deletion authoritative and runs
/// [deletePhotoCompatibilityRow] inside the same outer database transaction.
class LegacyPhotoImageDeletionService {
  const LegacyPhotoImageDeletionService({
    required this.database,
    required this.objectStore,
    required this.systemObjects,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;

  /// Returns the exact mapped legacy Photo id, or null for an Image with no
  /// compatibility ownership. Any ambiguous/malformed state fails closed.
  Future<int?> mappedPhotoIdForDeletion({
    required int workspaceId,
    required int objectTypeId,
    required int objectId,
  }) async {
    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null || objectType.workspaceId != workspaceId)
      return null;
    final systemKey = await systemObjects.systemKeyForObjectType(objectTypeId);
    if (systemKey != ImageObjectService.systemKey) return null;

    final legacyIdProperties = objectType.properties
        .where((property) => property.name == 'Legacy Photo ID')
        .toList(growable: false);
    if (legacyIdProperties.length > 1) {
      throw const LegacyPhotoImageDeletionSafetyException();
    }

    AppObject? targetObject;
    int? storedLegacyPhotoId;
    for (final object in await objectStore.listObjects(objectTypeId)) {
      if (object.id != objectId) continue;
      targetObject = object;
      if (legacyIdProperties.isEmpty) break;
      final raw = object.values[legacyIdProperties.single.id];
      if (raw == null) break;
      storedLegacyPhotoId = _parsePositiveInt(raw);
      if (storedLegacyPhotoId == null) {
        throw const LegacyPhotoImageDeletionSafetyException();
      }
      break;
    }

    try {
      final table = await database
          .customSelect(
            '''SELECT 1 AS present
           FROM sqlite_master
           WHERE type = 'table' AND name = ?
           LIMIT 1''',
            variables: const [Variable<String>('photo_object_links')],
          )
          .getSingleOrNull();
      if (table == null) {
        if (storedLegacyPhotoId != null) {
          throw const LegacyPhotoImageDeletionSafetyException();
        }
        return null;
      }

      final objectMappings = await database
          .customSelect(
            '''SELECT workspace_id, photo_id
           FROM photo_object_links
           WHERE object_id = ?
           ORDER BY workspace_id, photo_id''',
            variables: [Variable<int>(objectId)],
          )
          .get();
      if (objectMappings.isEmpty) {
        if (storedLegacyPhotoId != null) {
          throw const LegacyPhotoImageDeletionSafetyException();
        }
        return null;
      }
      if (objectMappings.length != 1 || targetObject == null) {
        throw const LegacyPhotoImageDeletionSafetyException();
      }

      final mapping = objectMappings.single;
      final mappedWorkspaceId = mapping.read<int>('workspace_id');
      final mappedPhotoId = mapping.read<int>('photo_id');
      if (mappedWorkspaceId != workspaceId || mappedPhotoId <= 0) {
        throw const LegacyPhotoImageDeletionSafetyException();
      }
      if (storedLegacyPhotoId != null && storedLegacyPhotoId != mappedPhotoId) {
        throw const LegacyPhotoImageDeletionSafetyException();
      }

      // One legacy Photo may be promoted independently into multiple
      // workspaces. Deleting that shared Photo row from one workspace would
      // invalidate the other workspace's mirror, so retain both sides.
      final photoMappings = await database
          .customSelect(
            '''SELECT workspace_id, object_id
           FROM photo_object_links
           WHERE photo_id = ?
           ORDER BY workspace_id, object_id''',
            variables: [Variable<int>(mappedPhotoId)],
          )
          .get();
      if (photoMappings.length != 1 ||
          photoMappings.single.read<int>('workspace_id') != workspaceId ||
          photoMappings.single.read<int>('object_id') != objectId) {
        throw const LegacyPhotoImageDeletionSafetyException();
      }

      final photoRows = await (database.select(
        database.photos,
      )..where((photo) => photo.id.equals(mappedPhotoId))).get();
      if (photoRows.length != 1) {
        throw const LegacyPhotoImageDeletionSafetyException();
      }

      final fileProperties = objectType.properties
          .where((property) => property.name == 'File')
          .toList(growable: false);
      if (fileProperties.length != 1) {
        throw const LegacyPhotoImageDeletionSafetyException();
      }
      final imageFilePath =
          '${targetObject.values[fileProperties.single.id] ?? ''}'.trim();
      final photoFilePath = photoRows.single.path.trim();
      if (imageFilePath.isEmpty || photoFilePath.isEmpty) {
        throw const LegacyPhotoImageDeletionSafetyException();
      }
      if (database.pathResolver.canonicalStoredPath(imageFilePath) !=
          database.pathResolver.canonicalStoredPath(photoFilePath)) {
        throw const LegacyPhotoImageDeletionSafetyException();
      }

      return mappedPhotoId;
    } on LegacyPhotoImageDeletionSafetyException {
      rethrow;
    } catch (_) {
      throw const LegacyPhotoImageDeletionSafetyException();
    }
  }

  /// Mirrors the existing AppDatabase legacy Photo deletion semantics without
  /// opening a nested transaction. The caller must provide the outer atomic
  /// deletion transaction.
  Future<void> deletePhotoCompatibilityRow(int photoId) async {
    if (photoId <= 0) {
      throw const LegacyPhotoImageDeletionSafetyException();
    }

    await (database.update(database.people)
          ..where((person) => person.profilePhotoId.equals(photoId)))
        .write(const PeopleCompanion(profilePhotoId: Value(null)));
    final deleted = await (database.delete(
      database.photos,
    )..where((photo) => photo.id.equals(photoId))).go();
    if (deleted != 1) {
      throw const LegacyPhotoImageDeletionSafetyException();
    }
  }

  int? _parsePositiveInt(Object raw) {
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is num) {
      if (!raw.isFinite) return null;
      final parsed = raw.toInt();
      return parsed > 0 && raw == parsed ? parsed : null;
    }
    final parsed = int.tryParse('$raw');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
