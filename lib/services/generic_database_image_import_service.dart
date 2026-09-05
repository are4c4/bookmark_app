import 'dart:io';

import 'package:image/image.dart' as image;

import '../data/generic_database_object_create_service.dart';
import 'photo_storage_service.dart';

/// Imports user-selected image files into app-managed storage and then creates
/// canonical system Image Objects for a Database collection.
///
/// File picking/copying remains owned by [PhotoStorageService], while Object
/// identity/reuse remains owned by [GenericDatabaseObjectCreateService]. This
/// workflow only composes the two boundaries and removes a copied managed file
/// if canonical Object creation fails.
class GenericDatabaseImageImportService {
  const GenericDatabaseImageImportService({
    required this.photoStorage,
    required this.objectCreate,
  });

  final PhotoStorageService photoStorage;
  final GenericDatabaseObjectCreateService objectCreate;

  Future<List<int>> pickAndImport({required int databaseId}) async {
    final imported = await photoStorage.importImages();
    return _createImported(databaseId: databaseId, imported: imported);
  }

  Future<List<int>> importPaths({
    required int databaseId,
    required Iterable<String> sourcePaths,
  }) async {
    final imported = await photoStorage.importPaths(sourcePaths);
    return _createImported(databaseId: databaseId, imported: imported);
  }

  Future<List<int>> _createImported({
    required int databaseId,
    required List<ImportedPhoto> imported,
  }) async {
    if (imported.isEmpty) return const <int>[];

    final objectIds = <int>[];
    for (final photo in imported) {
      try {
        final geometry = await _probeGeometry(photo.path);
        objectIds.add(
          await objectCreate.createImageFromManagedFile(
            databaseId: databaseId,
            filePath: photo.path,
            originalFilename: photo.originalName,
            contentType: _contentType(photo.originalName),
            pixelWidth: geometry?.width,
            pixelHeight: geometry?.height,
          ),
        );
      } catch (_) {
        await photoStorage.deleteManagedPhoto(photo.path);
        rethrow;
      }
    }
    return objectIds;
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
