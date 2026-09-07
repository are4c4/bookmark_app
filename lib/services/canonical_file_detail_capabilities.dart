import '../data/app_database.dart';
import '../data/file_object_service.dart';
import '../data/object_store.dart';
import '../data/system_object_store.dart';
import 'canonical_file_action_service.dart';
import 'canonical_file_export_service.dart';
import 'canonical_file_pdf_metadata_service.dart';
import 'canonical_file_pdf_page_count_service.dart';
import 'canonical_file_pdf_preview_service.dart';
import 'file_managed_resource_resolver.dart';

/// Service-layer composition for the native capabilities of canonical File.
///
/// Presentation code receives this typed bundle instead of reaching through to
/// [AppDatabase] to build resolvers/services itself. Canonical primitive
/// identity is checked here as part of the same service boundary, so custom
/// ObjectTypes that merely contain File Properties never acquire native File
/// behavior structurally.
class CanonicalFileDetailCapabilities {
  CanonicalFileDetailCapabilities._({
    required SystemObjectStore systemObjects,
    required this.actions,
    required this.exporter,
    required this.preview,
    required this.pdfMetadata,
    required this.pdfPageCount,
  }) : _systemObjects = systemObjects;

  factory CanonicalFileDetailCapabilities.fromDatabase({
    required AppDatabase database,
    required ObjectStore objectStore,
  }) {
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final resources = CanonicalFileManagedResourceResolver(
      objectStore: objectStore,
      systemObjects: systemObjects,
      pathResolver: database.pathResolver,
    );
    return CanonicalFileDetailCapabilities._(
      systemObjects: systemObjects,
      actions: CanonicalFileActionService(resources: resources),
      exporter: CanonicalFileExportService(resources: resources),
      preview: CanonicalFilePdfPreviewService(resources: resources),
      pdfMetadata: CanonicalFilePdfMetadataService(resources: resources),
      pdfPageCount: CanonicalFilePdfPageCountService(resources: resources),
    );
  }

  final SystemObjectStore _systemObjects;
  final CanonicalFileActionService actions;
  final CanonicalFileExportService exporter;
  final CanonicalFilePdfPreviewService preview;
  final CanonicalFilePdfMetadataService pdfMetadata;
  final CanonicalFilePdfPageCountService pdfPageCount;

  Future<bool> supports({
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    if (fileObjectTypeId <= 0 || fileObjectId <= 0) return false;
    final systemKey = await _systemObjects.systemKeyForObjectType(
      fileObjectTypeId,
    );
    return systemKey == FileObjectService.systemKey;
  }
}
