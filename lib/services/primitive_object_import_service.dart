import 'dart:io';

import 'primitive_file_import_classifier.dart';

typedef PrimitiveCanonicalPathImporter = Future<int> Function({
  required int databaseId,
  required String sourcePath,
  String? contentType,
});

class PrimitiveObjectImportResult {
  const PrimitiveObjectImportResult({
    required this.objectId,
    required this.target,
    required this.evidence,
    this.contentType,
  });

  final int objectId;
  final PrimitiveFileImportTarget target;
  final PrimitiveFileImportEvidence evidence;
  final String? contentType;
}

/// Routes user-selected source files into exactly one canonical primitive path.
///
/// This service owns only the Image-vs-File product decision. The injected
/// importers own managed copying and canonical Object identity. In particular,
/// the File importer can be backed by the Storage/Vault lane's managed-copy
/// boundary while Image continues to use the existing canonical Image import
/// workflow.
///
/// A failure from the selected importer is propagated as-is and never falls
/// through to the other primitive. This prevents one user action from creating
/// both an Image and a File Object after a partial failure.
class PrimitiveObjectImportService {
  const PrimitiveObjectImportService({
    this.classifier = const PrimitiveFileImportClassifier(),
    required this.importImage,
    required this.importFile,
  });

  final PrimitiveFileImportClassifier classifier;
  final PrimitiveCanonicalPathImporter importImage;
  final PrimitiveCanonicalPathImporter importFile;

  Future<PrimitiveObjectImportResult> importPath({
    required int databaseId,
    required String sourcePath,
    String? declaredContentType,
  }) async {
    final path = sourcePath.trim();
    if (path.isEmpty) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'Primitive import source path must not be empty.',
      );
    }

    FileStat stat;
    try {
      stat = await File(path).stat();
    } on FileSystemException {
      throw StateError('Primitive import source is not an available file.');
    }
    if (stat.type != FileSystemEntityType.file) {
      throw StateError('Primitive import source is not an available file.');
    }

    final classification = await classifier.classifyPath(
      path: path,
      declaredContentType: declaredContentType,
    );

    final importer = switch (classification.target) {
      PrimitiveFileImportTarget.image => importImage,
      PrimitiveFileImportTarget.file => importFile,
    };

    final objectId = await importer(
      databaseId: databaseId,
      sourcePath: path,
      contentType: classification.contentType,
    );
    if (objectId <= 0) {
      throw StateError('Primitive import delegate returned an invalid Object id.');
    }

    return PrimitiveObjectImportResult(
      objectId: objectId,
      target: classification.target,
      evidence: classification.evidence,
      contentType: classification.contentType,
    );
  }

  /// Routes a multi-file user action while preserving source order.
  ///
  /// Each source path is validated, classified independently and delegated
  /// exactly once. If one import fails, processing stops immediately and the
  /// selected importer remains responsible for its own rollback semantics.
  Future<List<PrimitiveObjectImportResult>> importPaths({
    required int databaseId,
    required Iterable<String> sourcePaths,
    Map<String, String?> declaredContentTypes = const <String, String?>{},
  }) async {
    final results = <PrimitiveObjectImportResult>[];
    for (final sourcePath in sourcePaths) {
      results.add(
        await importPath(
          databaseId: databaseId,
          sourcePath: sourcePath,
          declaredContentType: declaredContentTypes[sourcePath],
        ),
      );
    }
    return results;
  }
}
