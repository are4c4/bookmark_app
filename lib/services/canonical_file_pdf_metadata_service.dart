import 'file_managed_resource_resolver.dart';
import 'pdf_metadata_service.dart';
import 'primitive_file_import_classifier.dart';

typedef CanonicalPdfMetadataReader = Future<PdfFileMetadata> Function(
  String filePath,
);

class CanonicalFilePdfMetadata {
  const CanonicalFilePdfMetadata({
    required this.fileObjectId,
    required this.title,
    required this.authors,
  });

  final int fileObjectId;
  final String title;
  final List<String> authors;
}

/// Optional PDF metadata capability layered on the canonical File primitive.
///
/// PDF is never a separate Object identity here. The canonical File resource is
/// resolved through the system-identity-gated resolver, then classified by
/// content/MIME using the same routing policy as imports. Metadata extraction
/// runs only when that evidence identifies `application/pdf`.
class CanonicalFilePdfMetadataService {
  CanonicalFilePdfMetadataService({
    required CanonicalFileManagedResourceResolver resources,
    PrimitiveFileImportClassifier classifier =
        const PrimitiveFileImportClassifier(),
    CanonicalPdfMetadataReader? readMetadata,
  })  : _resources = resources,
        _classifier = classifier,
        _readMetadata = readMetadata ?? const PdfMetadataService().read;

  final CanonicalFileManagedResourceResolver _resources;
  final PrimitiveFileImportClassifier _classifier;
  final CanonicalPdfMetadataReader _readMetadata;

  Future<CanonicalFilePdfMetadata?> resolve({
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

    final metadata = await _readMetadata(resource.filePath);
    return CanonicalFilePdfMetadata(
      fileObjectId: resource.fileObjectId,
      title: metadata.title,
      authors: List<String>.unmodifiable(metadata.authors),
    );
  }
}
