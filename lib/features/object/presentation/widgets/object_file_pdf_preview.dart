import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../services/canonical_file_pdf_preview_service.dart';

typedef ObjectFilePdfPreviewResolver = Future<CanonicalFilePdfPreview?> Function({
  required int fileObjectTypeId,
  required int fileObjectId,
});

typedef ObjectFilePdfPreviewImageBuilder = Widget Function(
  BuildContext context,
  List<int> pngBytes,
);

/// Read-only inline PDF preview seam for the canonical File detail surface.
///
/// PDF remains a File Object. Production callers delegate capability detection
/// and transient preview generation to [CanonicalFilePdfPreviewService]. A
/// missing/non-PDF/unavailable preview renders nothing so ordinary File detail
/// pages do not gain a misleading PDF-specific empty state.
class ObjectFilePdfPreview extends StatefulWidget {
  const ObjectFilePdfPreview({
    super.key,
    this.previewService,
    required this.fileObjectTypeId,
    required this.fileObjectId,
    this.maxHeight = 420,
    this.previewResolver,
    this.imageBuilder,
    this.onError,
  }) : assert(
          previewService != null || previewResolver != null,
          'Provide a canonical PDF preview service or an injected resolver.',
        );

  /// Production capability source. Focused widget tests may leave this null and
  /// inject [previewResolver] instead.
  final CanonicalFilePdfPreviewService? previewService;
  final int fileObjectTypeId;
  final int fileObjectId;
  final double maxHeight;

  /// Test/presentation seam for the asynchronous capability read. Production
  /// hosts leave this null and continue using [previewService].
  final ObjectFilePdfPreviewResolver? previewResolver;
  final ObjectFilePdfPreviewImageBuilder? imageBuilder;

  /// Receives unexpected resolver failures for host logging/telemetry. The
  /// error is never rendered directly because it may contain filesystem data.
  final void Function(Object error)? onError;

  @override
  State<ObjectFilePdfPreview> createState() => _ObjectFilePdfPreviewState();
}

class _ObjectFilePdfPreviewState extends State<ObjectFilePdfPreview> {
  late Future<CanonicalFilePdfPreview?> _preview;

  @override
  void initState() {
    super.initState();
    _preview = _resolve();
  }

  @override
  void didUpdateWidget(covariant ObjectFilePdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewService != widget.previewService ||
        oldWidget.fileObjectTypeId != widget.fileObjectTypeId ||
        oldWidget.fileObjectId != widget.fileObjectId ||
        oldWidget.previewResolver != widget.previewResolver) {
      _preview = _resolve();
    }
  }

  Future<CanonicalFilePdfPreview?> _resolve() async {
    try {
      final customResolver = widget.previewResolver;
      if (customResolver != null) {
        return await customResolver(
          fileObjectTypeId: widget.fileObjectTypeId,
          fileObjectId: widget.fileObjectId,
        );
      }
      return await widget.previewService!.resolve(
        fileObjectTypeId: widget.fileObjectTypeId,
        fileObjectId: widget.fileObjectId,
      );
    } catch (error) {
      widget.onError?.call(error);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CanonicalFilePdfPreview?>(
      future: _preview,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final preview = snapshot.data;
        if (preview == null || preview.pngBytes.isEmpty) {
          return const SizedBox.shrink();
        }

        final scheme = Theme.of(context).colorScheme;
        final image = widget.imageBuilder?.call(context, preview.pngBytes) ??
            Image.memory(
              Uint8List.fromList(preview.pngBytes),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );

        return ConstrainedBox(
          key: ValueKey('object-file-pdf-preview-${widget.fileObjectId}'),
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: double.infinity,
                height: widget.maxHeight,
                child: image,
              ),
            ),
          ),
        );
      },
    );
  }
}
