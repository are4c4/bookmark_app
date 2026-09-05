import 'dart:developer' as developer;

import '../data/weblink_object_service.dart';
import 'bookmark_metadata_service.dart';

typedef WeblinkMetadataFetch = Future<BookmarkMetadata> Function(String url);
typedef WeblinkPreviewImageIngest = Future<int?> Function({
  required int workspaceId,
  required int weblinkObjectId,
});

/// Best-effort resource enrichment after canonical Weblink identity exists.
///
/// URL normalization/reuse stays in [WeblinkObjectService]. This service only
/// adds optional page metadata and delegates managed preview ingestion through
/// the existing canonical Weblink -> Image pipeline supplied by the composition
/// root. Failure here must never undo or block successful Weblink creation.
class WeblinkCreateEnrichmentService {
  const WeblinkCreateEnrichmentService({
    required this.weblinks,
    required this.metadataFetch,
    this.previewImageIngest,
  });

  final WeblinkObjectService weblinks;
  final WeblinkMetadataFetch metadataFetch;
  final WeblinkPreviewImageIngest? previewImageIngest;

  Future<void> enrich({
    required int workspaceId,
    required int objectId,
    required String url,
  }) async {
    BookmarkMetadata? metadata;
    try {
      metadata = await metadataFetch(url);
    } catch (error, stackTrace) {
      _debugFailure('metadata fetch', error, stackTrace);
    }

    if (metadata != null && _hasUsefulResourceMetadata(metadata)) {
      try {
        await weblinks.enrichIfMissing(
          workspaceId: workspaceId,
          objectId: objectId,
          pageTitle: metadata.title,
          description: metadata.description,
          previewImageUrl: metadata.thumbnail,
        );
      } catch (error, stackTrace) {
        _debugFailure('metadata persistence', error, stackTrace);
      }
    }

    final ingest = previewImageIngest;
    if (ingest == null) return;
    try {
      await ingest(
        workspaceId: workspaceId,
        weblinkObjectId: objectId,
      );
    } catch (error, stackTrace) {
      _debugFailure('preview ingestion', error, stackTrace);
    }
  }

  bool _hasUsefulResourceMetadata(BookmarkMetadata metadata) {
    final title = metadata.title.trim();
    final description = metadata.description?.trim();
    final thumbnail = metadata.thumbnail?.trim();
    if (description?.isNotEmpty == true || thumbnail?.isNotEmpty == true) {
      return true;
    }

    final uri = Uri.tryParse(metadata.url.trim());
    final fallbackTitle = uri == null
        ? metadata.url.trim()
        : (uri.host.isEmpty ? uri.toString() : uri.host);
    return title.isNotEmpty && title != fallbackTitle;
  }

  void _debugFailure(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    assert(() {
      developer.log(
        'Optional Weblink create $stage failed; canonical Weblink is kept.',
        name: 'bookmark_app.weblink_create_enrichment',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }());
  }
}
