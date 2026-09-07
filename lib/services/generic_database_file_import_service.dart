import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../data/generic_database_object_create_service.dart';
import 'vault_managed_file_copy_service.dart';

typedef ManagedFileSha256Reader = Future<String> Function(String path);

/// Imports one source file that the primitive router has already classified as
/// canonical File content.
///
/// Filesystem placement and ownership come exclusively from
/// [VaultManagedFileCopyService]. Canonical File identity and metadata remain
/// owned by [GenericDatabaseObjectCreateService]. If Object creation fails, only
/// the exact copy represented by the Storage-owned receipt is rolled back; the
/// user-selected source file is never deleted or modified.
class GenericDatabaseFileImportService {
  GenericDatabaseFileImportService({
    required this.managedFiles,
    required this.objectCreate,
    required this.vaultDirectoryPath,
    ManagedFileSha256Reader? sha256Reader,
  }) : sha256Reader = sha256Reader ?? _readSha256;

  final VaultManagedFileCopyService managedFiles;
  final GenericDatabaseObjectCreateService objectCreate;
  final String vaultDirectoryPath;
  final ManagedFileSha256Reader sha256Reader;

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
      final sha256 = await _sha256BestEffort(copy.resolvedPath);
      return await objectCreate.createFileFromManagedFile(
        databaseId: databaseId,
        filePath: copy.storedPath,
        originalFilename: copy.originalFilename,
        contentType: contentType,
        sizeBytes: copy.sizeBytes,
        sha256: sha256,
        storageOwnership: copy.ownership.managedOwnership,
      );
    } catch (_) {
      await _rollbackBestEffort(copy);
      rethrow;
    }
  }

  Future<String?> _sha256BestEffort(String path) async {
    try {
      final candidate = (await sha256Reader(path)).trim().toLowerCase();
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(candidate)) return null;
      return candidate;
    } catch (_, stackTrace) {
      // Hashing is optional derived metadata. Never fail an otherwise valid
      // import or expose the managed/user path when the metadata probe fails.
      assert(() {
        developer.log(
          'Managed File SHA-256 probe failed; continuing without hash metadata.',
          name: 'GenericDatabaseFileImportService',
          stackTrace: stackTrace,
        );
        return true;
      }());
      return null;
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

Future<String> _readSha256(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}
