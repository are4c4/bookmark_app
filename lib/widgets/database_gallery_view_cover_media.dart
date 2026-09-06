import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/database_view_gallery_adapter.dart';
import '../data/database_view_gallery_cover_compatibility_service.dart';
import '../data/database_view_store.dart';
import '../data/object_store.dart';
import '../data/system_object_store.dart';
import '../features/database/presentation/widgets/database_gallery_cover_media.dart';
import '../features/database/presentation/widgets/weblink_gallery_media.dart';

/// View-aware Gallery media wrapper for generic Database cards.
///
/// The effective source is resolved through the compatibility service so an
/// explicit per-View setting always wins, custom unconfigured Views stay
/// media-free, and historical system ObjectType Galleries retain their existing
/// canonical media behavior until they persist a setting. Media resolution then
/// delegates to [DatabaseGalleryCoverMedia], which remains read-only/fail-closed.
class DatabaseGalleryViewCoverMedia extends StatefulWidget {
  const DatabaseGalleryViewCoverMedia({
    super.key,
    required this.database,
    required this.objectStore,
    required this.workspaceId,
    required this.view,
    required this.sourceObjectTypeId,
    required this.sourceObjectId,
    required this.mode,
    this.fixedHeight = 96,
    this.masonryFallbackHeight = 160,
    this.imageBuilder,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int workspaceId;
  final DatabaseViewConfig view;
  final int sourceObjectTypeId;
  final int sourceObjectId;
  final GalleryViewMode mode;
  final double fixedHeight;
  final double masonryFallbackHeight;
  final WeblinkGalleryImageBuilder? imageBuilder;

  @override
  State<DatabaseGalleryViewCoverMedia> createState() =>
      _DatabaseGalleryViewCoverMediaState();
}

class _DatabaseGalleryViewCoverMediaState
    extends State<DatabaseGalleryViewCoverMedia> {
  late Future<GalleryCoverSource> _source;

  @override
  void initState() {
    super.initState();
    _source = _resolveSource();
  }

  @override
  void didUpdateWidget(covariant DatabaseGalleryViewCoverMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.sourceObjectTypeId != widget.sourceObjectTypeId ||
        oldWidget.view.id != widget.view.id ||
        oldWidget.view.settings != widget.view.settings) {
      _source = _resolveSource();
    }
  }

  Future<GalleryCoverSource> _resolveSource() =>
      DatabaseViewGalleryCoverCompatibilityService(
        objectStore: widget.objectStore,
        systemObjects: SystemObjectStore(
          database: widget.database,
          objectStore: widget.objectStore,
        ),
      ).effectiveSource(
        view: widget.view,
        objectTypeId: widget.sourceObjectTypeId,
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<GalleryCoverSource>(
        future: _source,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            final height = widget.mode == GalleryViewMode.fixed
                ? widget.fixedHeight
                : widget.masonryFallbackHeight;
            return SizedBox(
              key: ValueKey(
                'database-gallery-view-cover-loading-${widget.sourceObjectId}',
              ),
              width: double.infinity,
              height: height,
            );
          }
          return DatabaseGalleryCoverMedia(
            database: widget.database,
            objectStore: widget.objectStore,
            workspaceId: widget.workspaceId,
            sourceObjectTypeId: widget.sourceObjectTypeId,
            sourceObjectId: widget.sourceObjectId,
            source: snapshot.data!,
            mode: widget.mode,
            fixedHeight: widget.fixedHeight,
            masonryFallbackHeight: widget.masonryFallbackHeight,
            imageBuilder: widget.imageBuilder,
          );
        },
      );
}
