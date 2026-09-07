import 'package:flutter/material.dart';

import '../../../../services/canonical_file_detail_capabilities.dart';
import 'object_file_detail_panel.dart';

typedef ObjectFileDetailPanelHostBuilder = Widget Function(
  BuildContext context, {
  required int fileObjectTypeId,
  required int fileObjectId,
});

/// Turn-key canonical File detail adapter for shared Object-detail hosts.
///
/// Native File/PDF composition and primitive identity live in the service-layer
/// [CanonicalFileDetailCapabilities] bundle. Presentation therefore does not
/// reach through to AppDatabase, and custom ObjectTypes that merely contain a
/// File Property still fail closed to no native File panel.
class ObjectFileDetailPanelHost extends StatefulWidget {
  const ObjectFileDetailPanelHost({
    super.key,
    required this.capabilities,
    required this.fileObjectTypeId,
    required this.fileObjectId,
    this.maxPreviewHeight = 420,
    this.onError,
    this.panelBuilder,
  });

  final CanonicalFileDetailCapabilities capabilities;
  final int fileObjectTypeId;
  final int fileObjectId;
  final double maxPreviewHeight;
  final ValueChanged<Object>? onError;

  /// Focused presentation seam. Production hosts leave this null and receive
  /// the fully composed canonical File panel. Widget tests may inject a cheap
  /// builder while keeping system-identity gating real in [capabilities].
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
    if (oldWidget.capabilities != widget.capabilities ||
        oldWidget.fileObjectTypeId != widget.fileObjectTypeId ||
        oldWidget.fileObjectId != widget.fileObjectId) {
      _isCanonicalFile = _resolveIdentity();
    }
  }

  Future<bool> _resolveIdentity() => widget.capabilities.supports(
        fileObjectTypeId: widget.fileObjectTypeId,
        fileObjectId: widget.fileObjectId,
      );

  Widget _buildCanonicalPanel(BuildContext context) {
    final injected = widget.panelBuilder;
    if (injected != null) {
      return injected(
        context,
        fileObjectTypeId: widget.fileObjectTypeId,
        fileObjectId: widget.fileObjectId,
      );
    }

    return ObjectFileDetailPanel(
      actions: widget.capabilities.actions,
      exporter: widget.capabilities.exporter,
      previewService: widget.capabilities.preview,
      pdfMetadataService: widget.capabilities.pdfMetadata,
      pdfPageCountService: widget.capabilities.pdfPageCount,
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
