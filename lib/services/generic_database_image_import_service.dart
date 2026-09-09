import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as image;

import '../data/generic_database_object_create_service.dart';
import '../domain/managed_file_ownership.dart';
import 'photo_storage_service.dart';
import 'primitive_file_import_classifier.dart';

typedef GenericDatabaseImagePicker = Future<List<String>> Function();

/// Stable user-facing boundary when an Image-collection selection resolves to
/// the File primitive instead. The message deliberately contains no source path.
class GenericDatabaseImageImportRequiresFileException implements Exception {
  const GenericDatabaseImageImportRequiresFileException();

  @override
  String toString() =>
      'Selected content does not belong to the supported Image primitive.';
}

/// Stable boundary when a selected source cannot be proven to be a regular file
/// before any managed Image copy is created.
class GenericDatabaseImageImportSourceUnavailableException implements Exception {
  const GenericDatabaseImageImportSourceUnavailableException();

  @override
  String toString() => 'Selected image is not available for import.';
}

/// Imports user-selected image files into app-managed storage and then creates
/// canonical system Image Objects for a Database collection.
///
/// Picker candidates are intentionally not extension-filtered. Every selected
/// source is classified before any managed-file mutation, so supported Image
/// content with a misleading filename can still reach canonical Image import.
/// Mixed/non-Image selections fail the whole preflight without creating managed
/// copies or Objects. Legacy Photo picking remains owned by [PhotoStorageService]
/// and keeps its historical extension-filtered behavior.
class GenericDatabaseImageImportService {
  GenericDatabaseImageImportService({
    required this.photoStorage,
    required this.objectCreate,
    PrimitiveFileImportClassifier classifier =
        const PrimitiveFileImportClassifier(),
    GenericDatabaseImagePicker? filePicker,
  })  : classifier = classifier,
        filePicker = filePicker ?? _pickPrimitiveImageCandidates;

  final PhotoStorageService photoStorage;
  final GenericDatabaseObjectCreateService objectCreate;
  final PrimitiveFileImportClassifier classifier;
  final GenericDatabaseImagePicker filePicker;

  Future<List<int>> pickAndImport({required int databaseId}) async {
    final sourcePaths = await filePicker();
    return importPaths(databaseId: databaseId, sourcePaths: sourcePaths);
  }

  Future<List<int>> importPaths({
    required int databaseId,
    required Iterable<String> sourcePaths,
  }) async {
    final prepared = <({String path, String contentType})>[];

    for (final rawPath in sourcePaths) {
      final path = rawPath.trim();
      if (path.isEmpty || !await _isRegularFile(path)) {
        throw const GenericDatabaseImageImportSourceUnavailableException();
      }
      final classification = await classifier.classifyPath(path: path);
      final contentType = classification.contentType;
      if (classification.target != PrimitiveFileImportTarget.image ||
          contentType == null ||
          contentType.isEmpty) {
        throw const GenericDatabaseImageImportRequiresFileException();
      }
      prepared.add((path: path, contentType: contentType));
    }

    final objectIds = <int>{};
    for (final item in prepared) {
      objectIds.add(
        await importClassifiedPath(
          databaseId: databaseId,
          sourcePath: item.path,
          contentType: item.contentType,
        ),
      );
    }
    return objectIds.toList(growable: false);
  }

  /// Imports one source that has already been classified as a supported Image
  /// by the canonical primitive router.
  ///
  /// Unlike the legacy picker path, this does not trust the source extension:
  /// `image/png` content named `document.pdf` is copied into managed Image
  /// storage with a codec-appropriate managed extension while preserving the
  /// original filename as provenance.
  Future<int> importClassifiedPath({
    required int databaseId,
    required String sourcePath,
    required String contentType,
  }) async {
    final photo = await photoStorage.importClassifiedImagePath(
      sourcePath: sourcePath,
      contentType: contentType,
      reuseIdentical: true,
    );
    if (photo == null) {
      throw const GenericDatabaseImageImportSourceUnavailableException();
    }
    final objectIds = await _createImported(
      databaseId: databaseId,
      imported: <ImportedPhoto>[photo],
    );
    if (objectIds.length != 1) {
      throw StateError('Classified Image import did not resolve one Object.');
    }
    return objectIds.single;
  }

  Future<List<int>> _createImported({
    required int databaseId,
    required List<ImportedPhoto> imported,
  }) async {
    if (imported.isEmpty) return const <int>[];

    final objectIds = <int>{};
    for (final photo in imported) {
      try {
        final geometry = await _probeGeometry(photo.path);
        objectIds.add(
          await objectCreate.createImageFromManagedFile(
            databaseId: databaseId,
            filePath: photo.path,
            originalFilename: photo.originalName,
            contentType: photo.contentType ?? _contentType(photo.originalName),
            pixelWidth: geometry?.width,
            pixelHeight: geometry?.height,
            storageOwnership: ManagedFileOwnership.vaultManagedCopy,
          ),
        );
      } catch (_) {
        if (photo.createdNew) {
          await _deleteManagedPhotoBestEffort(photo.path);
        }
        rethrow;
      }
    }
    return objectIds.toList(growable: false);
  }

  Future<bool> _isRegularFile(String path) async {
    try {
      return (await File(path).stat()).type == FileSystemEntityType.file;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _deleteManagedPhotoBestEffort(String path) async {
    try {
      await photoStorage.deleteManagedPhoto(path);
    } catch (_, stackTrace) {
      // Cleanup is rollback-only. Never replace the canonical Object-creation
      // failure with a secondary file-delete failure, and do not log paths or
      // exception text because either may contain user content.
      assert(() {
        developer.log(
          'Managed image import rollback cleanup failed.',
          name: 'GenericDatabaseImageImportService',
          stackTrace: stackTrace,
        );
        return true;
      }());
    }
  }

  Future<({int width, int height})?> _probeGeometry(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = image.decodeImage(bytes);
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        return null;
      }
      return (width: decoded.width, height: decoded.height);
    } catch (_) {
      // Dimensions are optional presentation metadata. Import identity must not
      // fail just because a supported image codec cannot expose geometry.
      return null;
    }
  }

  String? _contentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return null;
  }
}

Future<List<String>> _pickPrimitiveImageCandidates() async {
  const allFiles = XTypeGroup(label: '画像としてインポート');
  final selected = await openFiles(
    acceptedTypeGroups: const <XTypeGroup>[allFiles],
  );
  return selected.map((file) => file.path).toList(growable: false);
}
