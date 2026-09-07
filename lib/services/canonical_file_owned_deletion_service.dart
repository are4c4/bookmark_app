import 'dart:io';

import '../data/app_database.dart';
import '../data/object_store.dart';
import '../domain/managed_file_ownership.dart';
import '../domain/object_model.dart';
import 'file_managed_resource_resolver.dart';
import 'vault_managed_file_copy_service.dart';

enum CanonicalFileOwnedDeleteResult {
  deleted,
  alreadyMissing,
  retainedObjectStillPresent,
  retainedSharedReference,
  retainedAuditFailure,
}

/// Opaque two-phase receipt for deleting app-owned canonical File bytes.
///
/// Callers must capture the receipt before deleting the File Object, then pass
/// the same receipt back after Object/Relation deletion succeeds. The private
/// constructor prevents arbitrary paths or ownership grants from being forged.
class CanonicalFileOwnedDeletionPlan {
  const CanonicalFileOwnedDeletionPlan._({
    required this.workspaceId,
    required this.fileObjectTypeId,
    required this.fileObjectId,
    required this.storedPath,
    required this.resolvedPath,
    required this.vaultDirectoryPath,
    required this.ownership,
  });

  final int workspaceId;
  final int fileObjectTypeId;
  final int fileObjectId;
  final String storedPath;
  final String resolvedPath;
  final String vaultDirectoryPath;
  final ManagedFileOwnership ownership;
}

/// Safely deletes physical bytes after a canonical File Object is removed.
///
/// Storage ownership is necessary but never sufficient. Before invoking the
/// Storage-owned physical delete boundary this service verifies that the File
/// Object is actually gone and that no surviving Object `file` Property or
/// legacy Photo still resolves to the same physical file. Any audit failure is
/// fail-closed and preserves bytes.
class CanonicalFileOwnedDeletionService {
  const CanonicalFileOwnedDeletionService({
    required this.database,
    required this.objectStore,
    required this.resources,
    required this.managedFiles,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final CanonicalFileManagedResourceResolver resources;
  final VaultManagedFileCopyService managedFiles;

  Future<CanonicalFileOwnedDeletionPlan?> prepare({
    required int workspaceId,
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    if (workspaceId <= 0 || fileObjectTypeId <= 0 || fileObjectId <= 0) {
      return null;
    }
    final type = await objectStore.getObjectType(fileObjectTypeId);
    if (type == null || type.workspaceId != workspaceId) return null;

    final resource = await resources.resolveManaged(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );
    if (resource == null ||
        resource.storageOwnership != ManagedFileOwnership.vaultManagedCopy) {
      return null;
    }
    final vaultDirectoryPath = database.profileDirectoryPath?.trim();
    if (vaultDirectoryPath == null || vaultDirectoryPath.isEmpty) return null;

    return CanonicalFileOwnedDeletionPlan._(
      workspaceId: workspaceId,
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
      storedPath: resource.storedPath,
      resolvedPath: resource.filePath,
      vaultDirectoryPath: vaultDirectoryPath,
      ownership: resource.storageOwnership!,
    );
  }

  Future<CanonicalFileOwnedDeleteResult> deletePreparedBytes(
    CanonicalFileOwnedDeletionPlan plan,
  ) async {
    try {
      final deletingType = await objectStore.getObjectType(plan.fileObjectTypeId);
      if (deletingType != null) {
        if (deletingType.workspaceId != plan.workspaceId) {
          return CanonicalFileOwnedDeleteResult.retainedAuditFailure;
        }
        final objects = await objectStore.listObjects(plan.fileObjectTypeId);
        if (objects.any((object) => object.id == plan.fileObjectId)) {
          return CanonicalFileOwnedDeleteResult.retainedObjectStillPresent;
        }
      }

      if (await _hasObjectFileReference(plan) ||
          await _hasLegacyPhotoReference(plan)) {
        return CanonicalFileOwnedDeleteResult.retainedSharedReference;
      }

      final result = await managedFiles.deleteOwnedCopy(
        storedPath: plan.storedPath,
        vaultDirectoryPath: plan.vaultDirectoryPath,
        ownershipStorageKey: plan.ownership.storageKey,
      );
      return switch (result) {
        VaultManagedFileDeleteResult.deleted =>
          CanonicalFileOwnedDeleteResult.deleted,
        VaultManagedFileDeleteResult.alreadyMissing =>
          CanonicalFileOwnedDeleteResult.alreadyMissing,
      };
    } catch (_) {
      // Retaining an orphaned managed file is recoverable. Removing bytes still
      // referenced by another Object/legacy Photo is not, so every audit/path/
      // filesystem failure preserves the file.
      return CanonicalFileOwnedDeleteResult.retainedAuditFailure;
    }
  }

  Future<bool> _hasObjectFileReference(
    CanonicalFileOwnedDeletionPlan plan,
  ) async {
    final types = await objectStore.listObjectTypes(plan.workspaceId);
    for (final type in types) {
      final fileProperties = type.properties
          .where((property) => property.type == ObjectPropertyType.file)
          .toList(growable: false);
      if (fileProperties.isEmpty) continue;

      for (final object in await objectStore.listObjects(type.id)) {
        for (final property in fileProperties) {
          final raw = object.values[property.id];
          if (raw == null) continue;
          if (raw is! String) {
            throw StateError('Stored File Property value is malformed.');
          }
          final candidate = raw.trim();
          if (candidate.isEmpty) continue;
          if (await _samePhysicalFile(candidate, plan.resolvedPath)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<bool> _hasLegacyPhotoReference(
    CanonicalFileOwnedDeletionPlan plan,
  ) async {
    final photos = await database.select(database.photos).get();
    for (final photo in photos) {
      if (await _samePhysicalFile(photo.path, plan.resolvedPath)) return true;
    }
    return false;
  }

  Future<bool> _samePhysicalFile(String storedPath, String targetPath) async {
    final resolved = database.pathResolver.resolveStoredPath(storedPath);
    final type = await FileSystemEntity.type(resolved, followLinks: true);
    if (type != FileSystemEntityType.file) return false;
    return FileSystemEntity.identical(resolved, targetPath);
  }
}
