import 'dart:developer' as developer;
import 'dart:io';

import 'package:image/image.dart' as image;

import '../data/generic_database_object_create_service.dart';
import 'photo_storage_service.dart';

/// Imports user-selected image files into app-managed storage and then creates
/// canonical system Image Objects for a Database collection.
///
/// File picking/copying remains owned by [PhotoStorageService], while Object
/// identity/reuse remains owned by [GenericDatabaseObjectCreateService]. This
/// workflow composes the two boundaries, reuses byte-identical managed files on
/// canonical Image reimport, returns each canonical Image Object id once, and
/// removes only newly copied files if canonical Object creation fails.
class GenericDatabaseImageImportService {
  const GenericDatabaseImageImportService({
    required this.photoStorage,
    required this.objectCreate,
  });

  final PhotoStorageService photoStorage;
  final GenericDatabaseObjectCreateService objectCreate;

  Future<List<int>> pickAndImport({required int databaseId}) async {
    final imported = await photoStorage.importImages(reuseIdentical: true);
    return _createImported(databaseId: databaseId, imported: imported);
  }

  Future<List<int>> importPaths({
    required int databaseId,
    required Iterable<String> sourcePaths,
  }) async {
    final imported = await photoStorage.importPaths(
      sourcePaths,
      reuseIdentical: true,
    );
    return _createImported(databaseId: databaseId, imported: imported);
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
      throw StateError('Classified Image source is not available.');
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
