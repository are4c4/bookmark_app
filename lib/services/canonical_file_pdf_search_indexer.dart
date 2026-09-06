import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../repositories/object_derived_search_text_store.dart';
import '../repositories/object_search_repository.dart';
import 'canonical_file_pdf_text_service.dart';
import 'file_managed_resource_resolver.dart';

/// Search-owned coordinator that projects optional PDF extracted text from the
/// canonical File primitive into the canonical Object search row.
///
/// PDF identity and extraction remain owned by the File primitive capability.
/// Search owns only the replaceable `pdf-text` contribution and the focused FTS
/// refresh needed to make the current contribution visible without rebuilding
/// unrelated Objects.
class CanonicalFilePdfSearchIndexer {
  CanonicalFilePdfSearchIndexer({
    required CanonicalFilePdfTextService pdfText,
    required ObjectDerivedSearchTextStore derivedText,
    required ObjectSearchRepository search,
  })  : _pdfText = pdfText,
        _derivedText = derivedText,
        _search = search;

  /// Production composition for one profile/database.
  ///
  /// Tests may inject [readText] while still exercising the real managed-path,
  /// content-classification, derived-text and FTS boundaries.
  factory CanonicalFilePdfSearchIndexer.forStore(
    GenericDatabaseStore genericStore, {
    CanonicalPdfTextReader? readText,
  }) {
    final objectStore = ObjectStore(genericStore);
    return CanonicalFilePdfSearchIndexer(
      pdfText: CanonicalFilePdfTextService(
        resources: FileManagedResourceResolver(
          objectStore,
          pathResolver: genericStore.database.pathResolver,
        ),
        readText: readText,
      ),
      derivedText: ObjectDerivedSearchTextStore(genericStore),
      search: ObjectSearchRepository(genericStore),
    );
  }

  static const String sourceKey = 'pdf-text';

  final CanonicalFilePdfTextService _pdfText;
  final ObjectDerivedSearchTextStore _derivedText;
  final ObjectSearchRepository _search;

  /// Refreshes one canonical File Object's PDF-derived search contribution.
  ///
  /// Returns true when current PDF text is available. If the managed resource
  /// is missing, is no longer a PDF, or yields blank extraction, any previous
  /// `pdf-text` contribution is removed before the focused Object refresh so no
  /// stale extracted token remains searchable.
  Future<bool> refresh({
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    final extracted = await _pdfText.resolve(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );

    if (extracted == null) {
      await _derivedText.clearSource(
        objectId: fileObjectId,
        sourceKey: sourceKey,
      );
      await _search.refreshObject(fileObjectId);
      return false;
    }

    if (extracted.fileObjectId != fileObjectId) {
      throw StateError(
        'Canonical PDF text resolved a different File Object identity.',
      );
    }

    await _derivedText.replace(
      objectId: fileObjectId,
      sourceKey: sourceKey,
      text: extracted.text,
    );
    await _search.refreshObject(fileObjectId);
    return true;
  }
}
