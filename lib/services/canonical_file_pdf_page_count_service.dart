import 'dart:io';

import 'file_managed_resource_resolver.dart';
import 'primitive_file_import_classifier.dart';

typedef CanonicalPdfPageCountReader = Future<int?> Function(String filePath);

class CanonicalFilePdfPageCount {
  const CanonicalFilePdfPageCount({
    required this.fileObjectId,
    required this.pageCount,
  });

  final int fileObjectId;
  final int pageCount;
}

/// Optional page-count capability layered on the canonical File primitive.
///
/// The managed resource is resolved and classified through the same
/// content-first boundary as the other PDF capabilities. PDF remains a File
/// Object; page count is derived read-only and is not a second persistence path.
class CanonicalFilePdfPageCountService {
  CanonicalFilePdfPageCountService({
    required FileManagedResourceResolver resources,
    PrimitiveFileImportClassifier classifier =
        const PrimitiveFileImportClassifier(),
    CanonicalPdfPageCountReader? readPageCount,
  })  : _resources = resources,
        _classifier = classifier,
        _readPageCount = readPageCount ?? _readSpotlightPageCount;

  final FileManagedResourceResolver _resources;
  final PrimitiveFileImportClassifier _classifier;
  final CanonicalPdfPageCountReader _readPageCount;

  Future<CanonicalFilePdfPageCount?> resolve({
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

    final pageCount = await _readPageCount(resource.filePath);
    if (pageCount == null || pageCount <= 0) return null;
    return CanonicalFilePdfPageCount(
      fileObjectId: resource.fileObjectId,
      pageCount: pageCount,
    );
  }

  static Future<int?> _readSpotlightPageCount(String filePath) async {
    if (!Platform.isMacOS) return null;
    try {
      final result = await Process.run(
        '/usr/bin/mdls',
        const ['-raw', '-name', 'kMDItemNumberOfPages'],
        runInShell: false,
      );
      if (result.exitCode != 0) return null;
      final value = int.tryParse(result.stdout.toString().trim());
      return value != null && value > 0 ? value : null;
    } catch (error) {
      assert(() {
        stderr.writeln(
          'CanonicalFilePdfPageCountService: PDF page count failed '
          '(${error.runtimeType})',
        );
        return true;
      }());
      return null;
    }
  }
}
