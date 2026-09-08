import 'dart:io';

import '../data/generic_database_page_services.dart';
import '../data/image_object_service.dart';
import '../data/object_type_defaults_store.dart';
import '../data/system_object_store.dart';
import '../data/workspace_store.dart';
import 'photo_storage_service.dart';
import 'primitive_file_import_classifier.dart';

/// Canonical Image import boundary for the legacy Bookmark Stage1 external-drop
/// host during Photo -> Image consolidation.
///
/// Stage1 historically accepted only image-like dropped files and ignored other
/// filesystem entries. Keep that product behavior while moving the write
/// authority from legacy `Photos` rows onto first-class Image Objects. Supported
/// Image content is identified by the shared content-aware classifier, so a
/// misleading filename cannot force a real Image back onto the legacy path.
class BookmarkStage1ImageDropImportService {
  BookmarkStage1ImageDropImportService({
    required WorkspaceStore workspaceStore,
    required int workspaceId,
    String? photoDirectoryPath,
    PrimitiveFileImportClassifier classifier =
        const PrimitiveFileImportClassifier(),
  })  : _workspaceId = workspaceId,
        _classifier = classifier,
        _services = GenericDatabasePageServices.fromWorkspaceStore(
          workspaceStore: workspaceStore,
          photoStorage: PhotoStorageService(
            photoDirectoryPath: photoDirectoryPath,
          ),
        );

  final int _workspaceId;
  final PrimitiveFileImportClassifier _classifier;
  final GenericDatabasePageServices _services;

  Future<List<int>> importDroppedPaths(Iterable<String> sourcePaths) async {
    final imagePaths = <String>[];
    for (final rawPath in sourcePaths) {
      final path = rawPath.trim();
      if (path.isEmpty || !await _isRegularFile(path)) continue;
      final classification = await _classifier.classifyPath(path: path);
      if (classification.target == PrimitiveFileImportTarget.image &&
          classification.contentType != null &&
          classification.contentType!.isNotEmpty) {
        imagePaths.add(path);
      }
    }
    if (imagePaths.isEmpty) return const <int>[];

    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: _services.genericStore.database,
        objectStore: _services.objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(_services.genericStore),
    );
    final definition = await images.ensureDefinition(_workspaceId);
    return _services.imageImport.importPaths(
      databaseId: definition.objectType.id,
      sourcePaths: imagePaths,
    );
  }

  Future<bool> _isRegularFile(String path) async {
    try {
      return (await File(path).stat()).type == FileSystemEntityType.file;
    } on FileSystemException {
      return false;
    }
  }
}
