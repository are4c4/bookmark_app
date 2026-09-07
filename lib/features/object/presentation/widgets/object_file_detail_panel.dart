import 'package:flutter/material.dart';

import '../../../../services/canonical_file_action_service.dart';
import '../../../../services/canonical_file_export_service.dart';
import '../../../../services/canonical_file_pdf_metadata_service.dart';
import '../../../../services/canonical_file_pdf_page_count_service.dart';
import '../../../../services/canonical_file_pdf_preview_service.dart';
import 'object_file_detail_actions.dart';
import 'object_file_pdf_preview.dart';
import 'object_file_pdf_summary.dart';

/// Canonical File detail presentation seam.
///
/// Shared Object-detail hosts can render one panel without learning how native
/// File actions or MIME-derived PDF capabilities are implemented. PDF remains
/// an optional capability of the same File Object; a non-PDF File simply
/// renders the native actions without reserving PDF-specific layout space.
class ObjectFileDetailPanel extends StatelessWidget {
  const ObjectFileDetailPanel({
    super.key,
    required this.actions,
    required this.exporter,
    this.previewService,
    this.pdfMetadataService,
    this.pdfPageCountService,
    required this.fileObjectTypeId,
    required this.fileObjectId,
    this.maxPreviewHeight = 420,
    this.previewResolver,
    this.previewImageBuilder,
    this.pdfMetadataResolver,
    this.pdfPageCountResolver,
    this.exportDestinationPicker,
    this.openAction,
    this.revealAction,
    this.exportAction,
    this.onError,
  }) : assert(
          previewService != null || previewResolver != null,
          'Provide a canonical PDF preview service or an injected resolver.',
        );

  final CanonicalFileActionService actions;
  final CanonicalFileExportService exporter;
  final CanonicalFilePdfPreviewService? previewService;
  final CanonicalFilePdfMetadataService? pdfMetadataService;
  final CanonicalFilePdfPageCountService? pdfPageCountService;
  final int fileObjectTypeId;
  final int fileObjectId;
  final double maxPreviewHeight;

  final ObjectFilePdfPreviewResolver? previewResolver;
  final ObjectFilePdfPreviewImageBuilder? previewImageBuilder;
  final ObjectFilePdfMetadataResolver? pdfMetadataResolver;
  final ObjectFilePdfPageCountResolver? pdfPageCountResolver;
  final ObjectFileExportDestinationPicker? exportDestinationPicker;
  final ObjectFileNativeAction? openAction;
  final ObjectFileNativeAction? revealAction;
  final ObjectFileExportAction? exportAction;
  final ValueChanged<Object>? onError;

  bool get _hasPdfSummary =>
      pdfMetadataService != null ||
      pdfPageCountService != null ||
      pdfMetadataResolver != null ||
      pdfPageCountResolver != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('object-file-detail-panel-$fileObjectId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObjectFilePdfPreview(
          previewService: previewService,
          fileObjectTypeId: fileObjectTypeId,
          fileObjectId: fileObjectId,
          maxHeight: maxPreviewHeight,
          bottomSpacing: 12,
          previewResolver: previewResolver,
          imageBuilder: previewImageBuilder,
          onError: onError,
        ),
        if (_hasPdfSummary)
          ObjectFilePdfSummary(
            metadataService: pdfMetadataService,
            pageCountService: pdfPageCountService,
            fileObjectTypeId: fileObjectTypeId,
            fileObjectId: fileObjectId,
            metadataResolver: pdfMetadataResolver,
            pageCountResolver: pdfPageCountResolver,
            bottomSpacing: 12,
            onError: onError,
          ),
        ObjectFileDetailActions(
          actions: actions,
          exporter: exporter,
          fileObjectTypeId: fileObjectTypeId,
          fileObjectId: fileObjectId,
          exportDestinationPicker: exportDestinationPicker,
          openAction: openAction,
          revealAction: revealAction,
          exportAction: exportAction,
          onError: onError,
        ),
      ],
    );
  }
}
