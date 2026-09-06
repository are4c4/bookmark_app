import 'dart:io';

import 'primitive_file_import_classifier.dart';

typedef PrimitiveFileImportDelegate = Future<int> Function(
  PrimitiveFileImportContext context,
);

class PrimitiveFileImportContext {
  const PrimitiveFileImportContext({
    required this.sourcePath,
    required this.originalFilename,
    required this.sizeBytes,
    required this.classification,
  });

  final String sourcePath;
  final String originalFilename;
  final int sizeBytes;
  final PrimitiveFileImportClassification classification;
}

class PrimitiveFileImportResult {
  const PrimitiveFileImportResult({
    required this.target,
    required this.objectId,
    required this.evidence,
    this.contentType,
  });

  final PrimitiveFileImportTarget target;
  final int objectId;
  final PrimitiveFileImportEvidence evidence;
  final String? contentType;
}

class PrimitiveFileImportRouter {
  const PrimitiveFileImportRouter({
    this.classifier = const PrimitiveFileImportClassifier(),
  });

  final PrimitiveFileImportClassifier classifier;

  Future<PrimitiveFileImportResult> importOne({
    required String sourcePath,
    String? declaredContentType,
    required PrimitiveFileImportDelegate importImage,
    required PrimitiveFileImportDelegate importFile,
  }) async {
    final normalizedPath = sourcePath.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'Primitive import source path must not be empty.',
      );
    }

    final source = File(normalizedPath);
    FileStat stat;
    try {
      stat = await source.stat();
    } on FileSystemException {
      throw StateError('Primitive import source is not an available file.');
    }
    if (stat.type != FileSystemEntityType.file) {
      throw StateError('Primitive import source is not an available file.');
    }

    final classification = await classifier.classifyPath(
      path: normalizedPath,
      declaredContentType: declaredContentType,
    );
    final context = PrimitiveFileImportContext(
      sourcePath: normalizedPath,
      originalFilename: _fileName(normalizedPath),
      sizeBytes: stat.size,
      classification: classification,
    );

    final objectId = switch (classification.target) {
      PrimitiveFileImportTarget.image => await importImage(context),
      PrimitiveFileImportTarget.file => await importFile(context),
    };
    if (objectId <= 0) {
      throw StateError('Primitive import delegate returned an invalid Object id.');
    }
    return PrimitiveFileImportResult(
      target: classification.target,
      objectId: objectId,
      evidence: classification.evidence,
      contentType: classification.contentType,
    );
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }
}
