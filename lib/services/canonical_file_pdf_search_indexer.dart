import '../data/file_object_service.dart';
import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../data/system_object_store.dart';
import '../repositories/object_derived_search_text_store.dart';
import '../repositories/object_search_repository.dart';
import 'canonical_file_pdf_text_service.dart';
import 'file_managed_resource_resolver.dart';

/// Search-owned coordinator that projects optional PDF extracted text from the
/// canonical File primitive into the canonical Object search row.
///
/// PDF identity and extraction remain owned by the File primitive capability.
/// Search owns only the replaceable `pdf-text` contribution plus the focused or
/// workspace FTS reconciliation needed to expose the current contribution.
class CanonicalFilePdfSearchIndexer {
  CanonicalFilePdfSearchIndexer({
    required CanonicalFilePdfTextService pdfText,
    required ObjectDerivedSearchTextStore derivedText,
    required ObjectSearchRepository search,
    required ObjectStore objectStore,
    required SystemObjectStore systemObjects,
  })  : _pdfText = pdfText,
        _derivedText = derivedText,
        _search = search,
        _objectStore = objectStore,
        _systemObjects = systemObjects;

  /// Production composition for one profile/database.
  ///
  /// Tests may inject [readText] while still exercising the real managed-path,
  /// canonical File identity check, content-classification, derived-text and
  /// FTS boundaries.
  factory CanonicalFilePdfSearchIndexer.forStore(
    GenericDatabaseStore genericStore, {
    CanonicalPdfTextReader? readText,
  }) {
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: genericStore.database,
      objectStore: objectStore,
    );
    return CanonicalFilePdfSearchIndexer(
      pdfText: CanonicalFilePdfTextService(
        resources: CanonicalFileManagedResourceResolver(
          objectStore: objectStore,
          systemObjects: systemObjects,
          pathResolver: genericStore.database.pathResolver,
        ),
        readText: readText,
      ),
      derivedText: ObjectDerivedSearchTextStore(genericStore),
      search: ObjectSearchRepository(genericStore),
      objectStore: objectStore,
      systemObjects: systemObjects,
    );
  }

  static const String sourceKey = 'pdf-text';

  final CanonicalFilePdfTextService _pdfText;
  final ObjectDerivedSearchTextStore _derivedText;
  final ObjectSearchRepository _search;
  final ObjectStore _objectStore;
  final SystemObjectStore _systemObjects;

  /// Reconciles current PDF-derived text for every canonical File in one
  /// workspace, then rebuilds that workspace's canonical Object search rows
  /// once. Non-File ObjectTypes are never sent through the PDF capability.
  ///
  /// This is the application-facing rebuild path used by Global Search: opening
  /// or explicitly refreshing search is sufficient for current PDF text to join
  /// the same Object index as title, Properties, Body and Relations.
  Future<void> rebuildWorkspace(int workspaceId) async {
    int? fileObjectTypeId;
    try {
      fileObjectTypeId = (await _systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: FileObjectService.systemKey,
      ))
          ?.id;
    } on FormatException {
      // File schema decoding intentionally fails closed. PDF extraction is an
      // optional Search contribution, so isolate that corrupt system type and
      // still let the canonical Object FTS rebuild healthy ObjectTypes.
      fileObjectTypeId = null;
    }

    if (fileObjectTypeId != null) {
      final files = await _objectStore.listObjects(fileObjectTypeId);
      for (final file in files) {
        await _replaceContribution(
          fileObjectTypeId: fileObjectTypeId,
          fileObjectId: file.id,
        );
      }
    }
    await _search.rebuildWorkspace(workspaceId);
  }

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
    final available = await _replaceContribution(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );
    await _search.refreshObject(fileObjectId);
    return available;
  }

  Future<bool> _replaceContribution({
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
    return true;
  }
}
