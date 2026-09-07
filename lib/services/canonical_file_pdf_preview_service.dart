import 'dart:io';

import 'file_managed_resource_resolver.dart';
import 'primitive_file_import_classifier.dart';

typedef CanonicalPdfPreviewRenderer = Future<List<int>?> Function(
  String filePath,
);

class CanonicalFilePdfPreview {
  const CanonicalFilePdfPreview({
    required this.fileObjectId,
    required this.pngBytes,
  });

  final int fileObjectId;
  final List<int> pngBytes;
}

/// Optional visual-preview capability layered on the canonical File primitive.
///
/// PDF remains a File Object. The canonical managed resource is resolved through
/// the system-identity-gated resolver and classified with the shared
/// content-first policy before native preview work runs. Preview bytes are
/// derived transiently and are not persisted as a parallel PDF storage model.
class CanonicalFilePdfPreviewService {
  CanonicalFilePdfPreviewService({
    required CanonicalFileManagedResourceResolver resources,
    PrimitiveFileImportClassifier classifier =
        const PrimitiveFileImportClassifier(),
    CanonicalPdfPreviewRenderer? renderPreview,
  })  : _resources = resources,
        _classifier = classifier,
        _renderPreview = renderPreview ?? _renderQuickLookPreview;

  final CanonicalFileManagedResourceResolver _resources;
  final PrimitiveFileImportClassifier _classifier;
  final CanonicalPdfPreviewRenderer _renderPreview;

  Future<CanonicalFilePdfPreview?> resolve({
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    final resource = await _resources.resolveManaged(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );
    if (resource == null) return null;

    final classification = await _classifier.classifyPath(
      path: resource.filePath,
      declaredContentType: resource.contentType,
    );
    if (classification.contentType != 'application/pdf') return null;

    final bytes = await _renderPreview(resource.filePath);
    if (bytes == null || bytes.isEmpty) return null;
    return CanonicalFilePdfPreview(
      fileObjectId: resource.fileObjectId,
      pngBytes: List<int>.unmodifiable(bytes),
    );
  }

  static Future<List<int>?> _renderQuickLookPreview(String filePath) async {
    if (!Platform.isMacOS) return null;
    Directory? outputDirectory;
    try {
      outputDirectory = await Directory.systemTemp.createTemp(
        'bookmark_file_preview_',
      );
      final result = await Process.run(
        '/usr/bin/qlmanage',
        ['-t', '-s', '512', '-o', outputDirectory.path, filePath],
        runInShell: false,
      );
      if (result.exitCode != 0) return null;

      final entries = await outputDirectory.list(followLinks: false).toList();
      final previews = entries.whereType<File>().where(
            (file) => file.path.toLowerCase().endsWith('.png'),
          );
      if (previews.length != 1) return null;
      final bytes = await previews.single.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (error) {
      assert(() {
        // Do not log file paths or exception text: either may expose private
        // user filesystem information.
        stderr.writeln(
          'CanonicalFilePdfPreviewService: PDF preview failed '
          '(${error.runtimeType})',
        );
        return true;
      }());
      return null;
    } finally {
      if (outputDirectory != null) {
        try {
          if (await outputDirectory.exists()) {
            await outputDirectory.delete(recursive: true);
          }
        } on FileSystemException {
          // Preview cleanup is best-effort. Never surface or log local paths.
        }
      }
    }
  }
}
