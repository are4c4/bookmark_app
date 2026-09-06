import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/database_view_gallery_adapter.dart';
import '../../../../data/database_view_gallery_cover_target_resolver.dart';
import '../../../../data/object_store.dart';
import '../../../../data/system_object_store.dart';
import 'image_gallery_media.dart';
import 'weblink_gallery_media.dart';

/// Shared Gallery media host for generic Object cards.
///
/// A configured View cover source is resolved to a canonical Image/Weblink
/// Object before dispatching to the existing primitive media presenters. The
/// widget never mutates Relation state. Explicit `none` removes the media band;
/// a configured source that cannot resolve safely keeps stable fallback geometry
/// so fixed and masonry layouts do not collapse unpredictably.
class DatabaseGalleryCoverMedia extends StatefulWidget {
  const DatabaseGalleryCoverMedia({
    super.key,
    required this.database,
    required this.objectStore,
    required this.workspaceId,
    required this.sourceObjectTypeId,
    required this.sourceObjectId,
    required this.source,
    required this.mode,
    this.fixedHeight = 96,
    this.masonryFallbackHeight = 160,
    this.imageBuilder,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int workspaceId;
  final int sourceObjectTypeId;
  final int sourceObjectId;
  final GalleryCoverSource source;
  final GalleryViewMode mode;
  final double fixedHeight;
  final double masonryFallbackHeight;
  final WeblinkGalleryImageBuilder? imageBuilder;

  @override
  State<DatabaseGalleryCoverMedia> createState() =>
      _DatabaseGalleryCoverMediaState();
}

class _DatabaseGalleryCoverMediaState extends State<DatabaseGalleryCoverMedia> {
  late Future<GalleryCoverTarget?> _target;

  @override
  void initState() {
    super.initState();
    _target = _resolve();
  }

  @override
  void didUpdateWidget(covariant DatabaseGalleryCoverMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.sourceObjectTypeId != widget.sourceObjectTypeId ||
        oldWidget.sourceObjectId != widget.sourceObjectId ||
        oldWidget.source != widget.source) {
      _target = _resolve();
    }
  }

  Future<GalleryCoverTarget?> _resolve() {
    if (widget.source.kind == GalleryCoverSourceKind.none) {
      return Future<GalleryCoverTarget?>.value(null);
    }
    return DatabaseViewGalleryCoverTargetResolver(
      objectStore: widget.objectStore,
      systemObjects: SystemObjectStore(
        database: widget.database,
        objectStore: widget.objectStore,
      ),
    ).resolve(
      sourceObjectTypeId: widget.sourceObjectTypeId,
      sourceObjectId: widget.sourceObjectId,
      source: widget.source,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.source.kind == GalleryCoverSourceKind.none) {
      return const SizedBox.shrink(
        key: ValueKey('database-gallery-cover-none'),
      );
    }

    return FutureBuilder<GalleryCoverTarget?>(
      future: _target,
      builder: (context, snapshot) {
        final target = snapshot.data;
        if (target == null) return _fallback(context);

        return switch (target.kind) {
          GalleryCoverTargetKind.image => ImageGalleryMedia(
              database: widget.database,
              objectStore: widget.objectStore,
              workspaceId: widget.workspaceId,
              objectTypeId: target.objectTypeId,
              objectId: target.objectId,
              mode: widget.mode,
              imageBuilder: widget.imageBuilder == null
                  ? null
                  : (context, path) => widget.imageBuilder!(
                        context,
                        path,
                        () => _placeholder(context),
                      ),
            ),
          GalleryCoverTargetKind.weblink => WeblinkGalleryMedia(
              database: widget.database,
              objectStore: widget.objectStore,
              workspaceId: widget.workspaceId,
              objectTypeId: target.objectTypeId,
              objectId: target.objectId,
              mode: widget.mode,
              fixedHeight: widget.fixedHeight,
              masonryFallbackHeight: widget.masonryFallbackHeight,
              imageBuilder: widget.imageBuilder,
            ),
        };
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final height = widget.mode == GalleryViewMode.fixed
        ? widget.fixedHeight
        : widget.masonryFallbackHeight;
    return SizedBox(
      key: ValueKey(
        widget.mode == GalleryViewMode.fixed
            ? 'database-gallery-cover-fallback-fixed-${widget.sourceObjectId}'
            : 'database-gallery-cover-fallback-masonry-${widget.sourceObjectId}',
      ),
      width: double.infinity,
      height: height,
      child: _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: scheme.onSurfaceVariant.withValues(alpha: .5),
        ),
      ),
    );
  }
}
