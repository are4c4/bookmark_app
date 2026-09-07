import 'package:flutter/material.dart';

import '../../../../services/canonical_file_pdf_metadata_service.dart';
import '../../../../services/canonical_file_pdf_page_count_service.dart';

typedef ObjectFilePdfMetadataResolver = Future<CanonicalFilePdfMetadata?> Function({
  required int fileObjectTypeId,
  required int fileObjectId,
});
typedef ObjectFilePdfPageCountResolver = Future<CanonicalFilePdfPageCount?> Function({
  required int fileObjectTypeId,
  required int fileObjectId,
});

class ObjectFilePdfSummaryData {
  const ObjectFilePdfSummaryData({
    this.title,
    this.authors = const <String>[],
    this.pageCount,
  });

  final String? title;
  final List<String> authors;
  final int? pageCount;

  bool get isEmpty => title == null && authors.isEmpty && pageCount == null;
}

/// Read-only PDF metadata summary for one canonical File Object.
///
/// Embedded PDF metadata and page count remain optional capabilities of the
/// same File identity. Each read fails soft independently: a metadata failure
/// does not hide a valid page count, and no raw error/path is rendered.
class ObjectFilePdfSummary extends StatefulWidget {
  const ObjectFilePdfSummary({
    super.key,
    this.metadataService,
    this.pageCountService,
    required this.fileObjectTypeId,
    required this.fileObjectId,
    this.metadataResolver,
    this.pageCountResolver,
    this.bottomSpacing = 0,
    this.onError,
  });

  final CanonicalFilePdfMetadataService? metadataService;
  final CanonicalFilePdfPageCountService? pageCountService;
  final int fileObjectTypeId;
  final int fileObjectId;
  final ObjectFilePdfMetadataResolver? metadataResolver;
  final ObjectFilePdfPageCountResolver? pageCountResolver;
  final double bottomSpacing;
  final ValueChanged<Object>? onError;

  bool get hasCapabilitySource =>
      metadataService != null ||
      pageCountService != null ||
      metadataResolver != null ||
      pageCountResolver != null;

  @override
  State<ObjectFilePdfSummary> createState() => _ObjectFilePdfSummaryState();
}

class _ObjectFilePdfSummaryState extends State<ObjectFilePdfSummary> {
  late Future<ObjectFilePdfSummaryData?> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _resolve();
  }

  @override
  void didUpdateWidget(covariant ObjectFilePdfSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadataService != widget.metadataService ||
        oldWidget.pageCountService != widget.pageCountService ||
        oldWidget.fileObjectTypeId != widget.fileObjectTypeId ||
        oldWidget.fileObjectId != widget.fileObjectId ||
        oldWidget.metadataResolver != widget.metadataResolver ||
        oldWidget.pageCountResolver != widget.pageCountResolver) {
      _summary = _resolve();
    }
  }

  Future<ObjectFilePdfSummaryData?> _resolve() async {
    if (!widget.hasCapabilitySource) return null;

    CanonicalFilePdfMetadata? metadata;
    CanonicalFilePdfPageCount? pageCount;

    try {
      final resolver = widget.metadataResolver;
      if (resolver != null) {
        metadata = await resolver(
          fileObjectTypeId: widget.fileObjectTypeId,
          fileObjectId: widget.fileObjectId,
        );
      } else if (widget.metadataService != null) {
        metadata = await widget.metadataService!.resolve(
          fileObjectTypeId: widget.fileObjectTypeId,
          fileObjectId: widget.fileObjectId,
        );
      }
    } catch (error) {
      widget.onError?.call(error);
    }

    try {
      final resolver = widget.pageCountResolver;
      if (resolver != null) {
        pageCount = await resolver(
          fileObjectTypeId: widget.fileObjectTypeId,
          fileObjectId: widget.fileObjectId,
        );
      } else if (widget.pageCountService != null) {
        pageCount = await widget.pageCountService!.resolve(
          fileObjectTypeId: widget.fileObjectTypeId,
          fileObjectId: widget.fileObjectId,
        );
      }
    } catch (error) {
      widget.onError?.call(error);
    }

    final title = _normalized(metadata?.title);
    final authors = metadata?.authors
            .map(_normalized)
            .whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    final validPageCount = pageCount != null && pageCount.pageCount > 0
        ? pageCount.pageCount
        : null;
    final summary = ObjectFilePdfSummaryData(
      title: title,
      authors: authors,
      pageCount: validPageCount,
    );
    return summary.isEmpty ? null : summary;
  }

  String? _normalized(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ObjectFilePdfSummaryData?>(
      future: _summary,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final summary = snapshot.data;
        if (summary == null) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        final content = Container(
          key: ValueKey('object-file-pdf-summary-${widget.fileObjectId}'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PDF情報',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (summary.title != null) ...[
                const SizedBox(height: 6),
                Text('タイトル  ${summary.title}'),
              ],
              if (summary.authors.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('著者  ${summary.authors.join(', ')}'),
              ],
              if (summary.pageCount != null) ...[
                const SizedBox(height: 4),
                Text('ページ数  ${summary.pageCount}'),
              ],
            ],
          ),
        );
        if (widget.bottomSpacing <= 0) return content;
        return Padding(
          padding: EdgeInsets.only(bottom: widget.bottomSpacing),
          child: content,
        );
      },
    );
  }
}
