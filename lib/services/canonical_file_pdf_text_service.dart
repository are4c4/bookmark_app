import 'dart:io';

import 'file_managed_resource_resolver.dart';
import 'primitive_file_import_classifier.dart';

typedef CanonicalPdfTextReader = Future<String?> Function(String filePath);

class CanonicalFilePdfText {
  const CanonicalFilePdfText({
    required this.fileObjectId,
    required this.text,
  });

  final int fileObjectId;
  final String text;
}

/// Optional extracted-text capability layered on the canonical File primitive.
///
/// PDF remains a File Object. The managed resource is resolved through the
/// system-identity-gated canonical File resolver and classified with the same
/// content-first policy as import before any text reader runs. Search/indexing
/// may consume the returned text, but this service does not own or write a
/// search index.
class CanonicalFilePdfTextService {
  CanonicalFilePdfTextService({
    required CanonicalFileManagedResourceResolver resources,
    PrimitiveFileImportClassifier classifier =
        const PrimitiveFileImportClassifier(),
    CanonicalPdfTextReader? readText,
  })  : _resources = resources,
        _classifier = classifier,
        _readText = readText ?? _readSpotlightText;

  final CanonicalFileManagedResourceResolver _resources;
  final PrimitiveFileImportClassifier _classifier;
  final CanonicalPdfTextReader _readText;

  Future<CanonicalFilePdfText?> resolve({
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

    final text = (await _readText(resource.filePath))?.trim();
    if (text == null || text.isEmpty) return null;
    return CanonicalFilePdfText(fileObjectId: resource.fileObjectId, text: text);
  }

  static Future<String?> _readSpotlightText(String filePath) async {
    if (!Platform.isMacOS) return null;
    try {
      final result = await Process.run(
        '/usr/bin/mdls',
        ['-raw', '-name', 'kMDItemTextContent', filePath],
        runInShell: false,
      );
      if (result.exitCode != 0) return null;
      final text = result.stdout.toString().trim();
      if (text.isEmpty || text == '(null)') return null;
      return text;
    } catch (error, stackTrace) {
      assert(() {
        // Do not log the local file path or exception text: either can contain
        // private user filesystem information.
        stderr.writeln(
          'CanonicalFilePdfTextService: PDF text read failed '
          '(${error.runtimeType})',
        );
        stderr.writeln(stackTrace);
        return true;
      }());
      return null;
    }
  }
}
