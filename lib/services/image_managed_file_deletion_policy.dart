import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/app_database.dart';
import '../data/image_object_service.dart';
import '../data/object_store.dart';
import 'photo_storage_service.dart';

/// Determines whether deleting one canonical Image Object may also remove its
/// physical app-managed file.
///
/// Object deletion and Relation lifecycle remain separate concerns. This policy
/// is read-only and returns a deletable path only when the candidate is inside
/// the active managed photo directory and no surviving canonical Image or
/// legacy Photo resolves to the same physical path. Any missing/ambiguous state
/// preserves the file.
class ImageManagedFileDeletionPolicy {
  const ImageManagedFileDeletionPolicy({
    required this.database,
    required this.objectStore,
    required this.photoStorage,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final PhotoStorageService photoStorage;

  Future<String?> deletableManagedPath({
    required int deletingObjectId,
    required String filePath,
  }) async {
    if (deletingObjectId <= 0) return null;
    final candidate = filePath.trim();
    if (candidate.isEmpty) return null;

    try {
      final resolvedCandidate = database.pathResolver.resolveStoredPath(candidate);
      final managedRoot = _managedPhotoRoot();
      if (managedRoot == null || !_isManagedPath(resolvedCandidate, managedRoot)) {
        return null;
      }

      final photos = await database.select(database.photos).get();
      for (final photo in photos) {
        final resolvedPhoto = database.pathResolver.resolveStoredPath(photo.path);
        if (_samePath(resolvedPhoto, resolvedCandidate)) return null;
      }

      final systemTable = await database.customSelect(
        '''SELECT 1 AS present
           FROM sqlite_master
           WHERE type = 'table' AND name = 'system_object_types'
           LIMIT 1''',
      ).getSingleOrNull();
      if (systemTable == null) return null;

      final imageTypeRows = await database.customSelect(
        '''SELECT object_type_id
           FROM system_object_types
           WHERE system_key = ?
           ORDER BY workspace_id, object_type_id''',
        variables: const [Variable<String>(ImageObjectService.systemKey)],
      ).get();
      if (imageTypeRows.isEmpty) return null;

      for (final row in imageTypeRows) {
        final objectTypeId = row.read<int>('object_type_id');
        final objectType = await objectStore.getObjectType(objectTypeId);
        if (objectType == null) return null;
        final fileProperties = objectType.properties
            .where((property) => property.name == 'File')
            .toList(growable: false);
        if (fileProperties.length != 1) return null;

        for (final object in await objectStore.listObjects(objectTypeId)) {
          if (object.id == deletingObjectId) continue;
          final storedFile =
              '${object.values[fileProperties.single.id] ?? ''}'.trim();
          if (storedFile.isEmpty) continue;
          final resolvedStored = database.pathResolver.resolveStoredPath(storedFile);
          if (_samePath(resolvedStored, resolvedCandidate)) return null;
        }
      }

      return resolvedCandidate;
    } catch (_) {
      // Retaining an orphan file is recoverable. Deleting a shared or external
      // user file is not, so any audit/read/path failure must fail closed.
      return null;
    }
  }

  String? _managedPhotoRoot() {
    final explicit = photoStorage.photoDirectoryPath?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final active = PhotoStorageService.activePhotoDirectoryPath?.trim();
    if (active != null && active.isNotEmpty) return active;
    final profile = database.profileDirectoryPath?.trim();
    if (profile == null || profile.isEmpty) return null;
    return '$profile/photos';
  }

  bool _isManagedPath(String candidate, String managedRoot) {
    final normalizedCandidate = p.normalize(p.absolute(candidate));
    final normalizedRoot = p.normalize(p.absolute(managedRoot));
    return p.isWithin(normalizedRoot, normalizedCandidate);
  }

  bool _samePath(String left, String right) =>
      p.normalize(p.absolute(left)) == p.normalize(p.absolute(right));
}
