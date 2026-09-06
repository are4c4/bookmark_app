import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/generic_database_store.dart';
import '../data/image_object_service.dart';
import '../data/object_store.dart';

/// Decides whether deleting one legacy Photo row may also delete its managed
/// file while first-class Image Objects coexist with the legacy subsystem.
///
/// A file is deletable only when every canonical Image that resolves to the same
/// profile/Vault path is the legacy-owned mirror for this exact Photo and is
/// still connected through `photo_object_links`. Any native/shared/ambiguous
/// Image reference preserves the physical file. The check is read-only and errs
/// on the side of retaining media when canonical Object state cannot be audited.
class PhotoManagedFileDeletionPolicy {
  PhotoManagedFileDeletionPolicy(this.database)
      : _objectStore = ObjectStore(GenericDatabaseStore(database));

  final AppDatabase database;
  final ObjectStore _objectStore;

  Future<bool> shouldPreserve({
    required int legacyPhotoId,
    required String filePath,
  }) async {
    if (legacyPhotoId <= 0) return true;
    final candidate = filePath.trim();
    if (candidate.isEmpty) return true;

    try {
      final resolvedCandidate = database.pathResolver.resolveStoredPath(candidate);
      final systemTableExists = await _tableExists('system_object_types');
      if (!systemTableExists) {
        // The canonical system-Object registry has never been bootstrapped, so
        // no first-class system Image can currently own this legacy file.
        return false;
      }

      final linkedObjectIds = await _linkedObjectIds(legacyPhotoId);
      final imageTypeRows = await database.customSelect(
        '''SELECT object_type_id
           FROM system_object_types
           WHERE system_key = ?
           ORDER BY workspace_id, object_type_id''',
        variables: const [Variable<String>(ImageObjectService.systemKey)],
      ).get();

      for (final row in imageTypeRows) {
        final objectTypeId = row.read<int>('object_type_id');
        final objectType = await _objectStore.getObjectType(objectTypeId);
        if (objectType == null) return true;

        final fileProperties = objectType.properties
            .where((property) => property.name == 'File')
            .toList(growable: false);
        if (fileProperties.length != 1) return true;
        final legacyIdProperties = objectType.properties
            .where((property) => property.name == 'Legacy Photo ID')
            .toList(growable: false);

        for (final object in await _objectStore.listObjects(objectTypeId)) {
          final storedFile =
              '${object.values[fileProperties.single.id] ?? ''}'.trim();
          if (storedFile.isEmpty) continue;
          final resolvedStored = database.pathResolver.resolveStoredPath(storedFile);
          if (resolvedStored != resolvedCandidate) continue;

          // Any Image outside this Photo's stable mapping shares the physical
          // asset independently, so legacy deletion cannot own the file.
          if (!linkedObjectIds.contains(object.id)) return true;
          if (legacyIdProperties.length != 1) return true;
          final rawLegacyId = object.values[legacyIdProperties.single.id];
          final imageLegacyId = rawLegacyId is int
              ? rawLegacyId
              : int.tryParse('${rawLegacyId ?? ''}');
          if (imageLegacyId != legacyPhotoId) return true;
        }
      }
      return false;
    } catch (_) {
      // A database/schema/read failure must not turn into destructive media
      // cleanup. Retaining a file is recoverable; deleting shared media is not.
      return true;
    }
  }

  Future<Set<int>> _linkedObjectIds(int legacyPhotoId) async {
    if (!await _tableExists('photo_object_links')) return <int>{};
    final rows = await database.customSelect(
      '''SELECT object_id
         FROM photo_object_links
         WHERE photo_id = ?''',
      variables: [Variable<int>(legacyPhotoId)],
    ).get();
    return rows.map((row) => row.read<int>('object_id')).toSet();
  }

  Future<bool> _tableExists(String tableName) async {
    final row = await database.customSelect(
      '''SELECT 1 AS present
         FROM sqlite_master
         WHERE type = 'table' AND name = ?
         LIMIT 1''',
      variables: [Variable<String>(tableName)],
    ).getSingleOrNull();
    return row != null;
  }
}
