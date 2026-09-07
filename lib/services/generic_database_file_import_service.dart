import 'dart:developer' as developer;

import '../data/generic_database_object_create_service.dart';
import 'vault_managed_file_copy_service.dart';

/// Imports one source file that the primitive router has already classified as
/// canonical File content.
///
/// Filesystem placement and ownership come exclusively from
/// [VaultManagedFileCopyService]. Canonical File identity and metadata remain
/// owned by [GenericDatabaseObjectCreateService]. If Object creation fails, only
/// the exact copy represented by the Storage-owned receipt is rolled back; the
/// user-selected source file is never deleted or modified.
class GenericDatabaseFileImportService {
  const GenericDatabaseFileImportService({
    required this.managedFiles,
    required this.objectCreate,
    required this.vaultDirectoryPath,
  });

  final VaultManagedFileCopyService managedFiles;
  final GenericDatabaseObjectCreateService objectCreate;
  final String vaultDirectoryPath;

  Future<int> importClassifiedPath({
    required int databaseId,
    required String sourcePath,
    String? contentType,
  }) async {
    final copy = await managedFiles.copyIntoVault(
      sourcePath: sourcePath,
      vaultDirectoryPath: vaultDirectoryPath,
    );

    try {
      return await objectCreate.createFileFromManagedFile(
        databaseId: databaseId,
        filePath: copy.storedPath,
        originalFilename: copy.originalFilename,
        contentType: contentType,
        sizeBytes: copy.sizeBytes,
        storageOwnership: copy.ownership.managedOwnership,
      );
    } catch (_) {
      await _rollbackBestEffort(copy);
      rethrow;
    }
  }

  Future<void> _rollbackBestEffort(VaultManagedFileCopy copy) async {
    try {
      await managedFiles.rollbackCopy(copy);
    } catch (_, stackTrace) {
      // Preserve the canonical Object-creation error. Never log source or
      // destination paths because either may contain user content.
      assert(() {
        developer.log(
          'Managed File import rollback cleanup failed.',
          name: 'GenericDatabaseFileImportService',
          stackTrace: stackTrace,
        );
        return true;
      }());
    }
  }
}
