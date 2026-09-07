import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/file_object_service.dart';
import '../../../../data/object_store.dart';
import '../../../../data/system_object_store.dart';
import '../../../../services/canonical_file_action_service.dart';
import '../../../../services/canonical_file_export_service.dart';
import '../../../../services/canonical_file_pdf_metadata_service.dart';
import '../../../../services/canonical_file_pdf_page_count_service.dart';
import '../../../../services/canonical_file_pdf_preview_service.dart';
import '../../../../services/file_managed_resource_resolver.dart';
import 'object_file_detail_panel.dart';

typedef ObjectFileDetailPanelHostBuilder = Widget Function(
  BuildContext context, {
  required int fileObjectTypeId,
  required int fileObjectId,
});

/// Turn-key canonical File detail adapter for shared Object-detail hosts.
///
/// The adapter verifies the registered system File identity before exposing any
/// native capability. Shared hosts therefore do not need to duplicate system-key
/// checks or construct filesystem/PDF services themselves. A custom ObjectType
/// that merely contains a File Property renders nothing here.
class ObjectFileDetailPanelHost extends StatefulWidget {
  const ObjectFileDetailPanelHost({
    super.key,
    required this.database,
    required this.objectStore,
    required this.fileObjectTypeId,
    required this.fileObjectId,
    this.maxPreviewHeight = 420,
    this.onError,
    this.panelBuilder,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int fileObjectTypeId;
  final int fileObjectId;
  final double maxPreviewHeight;
  final ValueChanged<Object>? onError;

  /// Focused presentation seam. Production hosts leave this null and receive
  /// the fully composed canonical File panel. Widget tests may inject a cheap
  /// builder while keeping system-identity gating real.
  final ObjectFileDetailPanelHostBuilder? panelBuilder;

  @override
  State<ObjectFileDetailPanelHost> createState() =>
      _ObjectFileDetailPanelHostState();
}

class _ObjectFileDetailPanelHostState extends State<ObjectFileDetailPanelHost> {
  late Future<bool> _isCanonicalFile;

  @override
  void initState() {
    super.initState();
    _isCanonicalFile = _resolveIdentity();
  }

  @override
  void didUpdateWidget(covariant ObjectFileDetailPanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.fileObjectTypeId != widget.fileObjectTypeId) {
      _isCanonicalFile = _resolveIdentity();
    }
  }

  SystemObjectStore _systemObjects() => SystemObjectStore(
        database: widget.database,
        objectStore: widget.objectStore,
      );

  Future<bool> _resolveIdentity() async {
    if (widget.fileObjectTypeId <= 0 || widget.fileObjectId <= 0) return false;
    final systemKey = await _systemObjects().systemKeyForObjectType(
      widget.fileObjectTypeId,
    );
    return systemKey == FileObjectService.systemKey;
  }

  Widget _buildCanonicalPanel(BuildContext context) {
    final injected = widget.panelBuilder;
    if (injected != null) {
      return injected(
        context,
        fileObjectTypeId: widget.fileObjectTypeId,
        fileObjectId: widget.fileObjectId,
      );
    }

    final resources = CanonicalFileManagedResourceResolver(
      objectStore: widget.objectStore,
      systemObjects: _systemObjects(),
      pathResolver: widget.database.pathResolver,
    );
    return ObjectFileDetailPanel(
      actions: CanonicalFileActionService(resources: resources),
      exporter: CanonicalFileExportService(resources: resources),
      previewService: CanonicalFilePdfPreviewService(resources: resources),
      pdfMetadataService: CanonicalFilePdfMetadataService(resources: resources),
      pdfPageCountService: CanonicalFilePdfPageCountService(resources: resources),
      fileObjectTypeId: widget.fileObjectTypeId,
      fileObjectId: widget.fileObjectId,
      maxPreviewHeight: widget.maxPreviewHeight,
      onError: widget.onError,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isCanonicalFile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.data != true) {
          return const SizedBox.shrink();
        }
        return _buildCanonicalPanel(context);
      },
    );
  }
}
