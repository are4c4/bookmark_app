import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';

import '../data/generic_database_object_create_service.dart';
import 'primitive_file_import_classifier.dart';
import 'vault_managed_file_copy_service.dart';

typedef ManagedFileSha256Reader = Future<String> Function(String path);
typedef GenericDatabaseFilePicker = Future<List<String>> Function();

/// Stable boundary when a File-collection picker receives content that belongs
/// to the canonical Image primitive instead.
class GenericDatabaseFileImportRequiresImageException implements Exception {
  const GenericDatabaseFileImportRequiresImageException();

  @override
  String toString() =>
      'Selected content belongs to the Image primitive and was not imported as File.';
}

/// Stable boundary when a picker/import source cannot be proven to be a regular
/// file before any managed-copy side effect starts.
class GenericDatabaseFileImportSourceUnavailableException implements Exception {
  const GenericDatabaseFileImportSourceUnavailableException();

  @override
  String toString() => 'Selected file is not available for import.';
}

/// Imports source files into app-managed storage and then creates canonical File
/// Objects for a Database collection.
///
/// The direct [importClassifiedPath] entry point is used after the shared
/// primitive router has already selected File. [pickAndImport] and
/// [importPickedPaths] perform their own mutation-free preflight first: every
/// source must be a regular file and classify as File before any Vault copy is
/// created. A supported Image in a mixed selection therefore fails the whole
/// File-collection action without partial File imports.
class GenericDatabaseFileImportService {
  GenericDatabaseFileImportService({
    required this.managedFiles,
    required this.objectCreate,
    required this.vaultDirectoryPath,
    PrimitiveFileImportClassifier classifier = const PrimitiveFileImportClassifier(),
    GenericDatabaseFilePicker? filePicker,
    ManagedFileSha256Reader? sha256Reader,
  })  : classifier = classifier,
        filePicker = filePicker ?? _pickFiles,
        sha256Reader = sha256Reader ?? _readSha256;

  final VaultManagedFileCopyService managedFiles;
  final GenericDatabaseObjectCreateService objectCreate;
  final String vaultDirectoryPath;
  final PrimitiveFileImportClassifier classifier;
  final GenericDatabaseFilePicker filePicker;
  final ManagedFileSha256Reader sha256Reader;

  Future<List<int>> pickAndImport({required int databaseId}) async {
    final sourcePaths = await filePicker();
    return importPickedPaths(
      databaseId: databaseId,
      sourcePaths: sourcePaths,
    );
  }

  /// Imports a File-collection selection only after every source passes
  /// content-first primitive classification.
  Future<List<int>> importPickedPaths({
    required int databaseId,
    required Iterable<String> sourcePaths,
  }) async {
    final prepared = <({
      String path,
      PrimitiveFileImportClassification classification,
    })>[];

    for (final rawPath in sourcePaths) {
      final path = rawPath.trim();
      if (path.isEmpty || !await _isRegularFile(path)) {
        throw const GenericDatabaseFileImportSourceUnavailableException();
      }
      final classification = await classifier.classifyPath(path: path);
      if (classification.target == PrimitiveFileImportTarget.image) {
        throw const GenericDatabaseFileImportRequiresImageException();
      }
      prepared.add((path: path, classification: classification));
    }

    final objectIds = <int>[];
    for (final item in prepared) {
      objectIds.add(
        await importClassifiedPath(
          databaseId: databaseId,
          sourcePath: item.path,
          contentType: item.classification.contentType,
        ),
      );
    }
    return objectIds;
  }

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

  Future<bool> _isRegularFile(String path) async {
    try {
      return (await File(path).stat()).type == FileSystemEntityType.file;
    } on FileSystemException {
      return false;
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

Future<List<String>> _pickFiles() async {
  const allFiles = XTypeGroup(label: 'ファイル');
  final selected = await openFiles(
    acceptedTypeGroups: const <XTypeGroup>[allFiles],
  );
  return selected.map((file) => file.path).toList(growable: false);
}

Future<String> _readSha256(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}
