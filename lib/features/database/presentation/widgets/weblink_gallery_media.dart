import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/database_view_gallery_adapter.dart';
import '../../../../data/image_object_service.dart';
import '../../../../data/object_store.dart';
import '../../../../data/system_object_store.dart';
import '../../../../data/weblink_object_service.dart';
import '../../../../services/weblink_visual_resolver.dart';
import 'image_gallery_media.dart';

enum _GalleryMediaKind { unsupported, weblink, image }

class _WeblinkGalleryMediaResolution {
  const _WeblinkGalleryMediaResolution({
    required this.kind,
    this.visual,
  });

  final _GalleryMediaKind kind;
  final WeblinkManagedVisual? visual;
}

typedef WeblinkGalleryImageBuilder = Widget Function(
  BuildContext context,
  String filePath,
  Widget Function() errorFallback,
);

/// Pure presentation frame for one resolved Weblink media item.
///
/// Resolution and Relation reads stay outside this widget so geometry can be
/// verified without a database, file codec, or asynchronous image stream.
class WeblinkGalleryMediaFrame extends StatelessWidget {
  const WeblinkGalleryMediaFrame({
    super.key,
    required this.objectId,
    required this.mode,
    required this.child,
    this.aspectRatio,
    this.fixedHeight = 96,
    this.masonryFallbackHeight = 160,
  });

  final int objectId;
  final GalleryViewMode mode;
  final Widget child;
  final double? aspectRatio;
  final double fixedHeight;
  final double masonryFallbackHeight;

  @override
  Widget build(BuildContext context) {
    if (mode == GalleryViewMode.fixed) {
      return SizedBox(
        key: ValueKey('weblink-gallery-media-fixed-$objectId'),
        width: double.infinity,
        height: fixedHeight,
        child: child,
      );
    }

    final ratio = aspectRatio;
    if (ratio != null && ratio.isFinite && ratio > 0) {
      return AspectRatio(
        key: ValueKey('weblink-gallery-media-ratio-$objectId'),
        aspectRatio: ratio,
        child: child,
      );
    }

    return SizedBox(
      key: ValueKey('weblink-gallery-media-fallback-$objectId'),
      width: double.infinity,
      height: masonryFallbackHeight,
      child: child,
    );
  }
}

/// Read-only managed media presentation for generic system-Object Gallery
/// cards.
///
/// Weblinks resolve their Representative Image through the shared
/// [WeblinkVisualResolver]. Canonical Image Objects delegate to
/// [ImageGalleryMedia] so the same generic Gallery host can present the managed
/// file itself without adding an Image-specific page or persistence path.
/// Unsupported/custom ObjectTypes stay media-free. This widget never mutates
/// Object or Relation state.
class WeblinkGalleryMedia extends StatefulWidget {
  const WeblinkGalleryMedia({
    super.key,
    required this.database,
    required this.objectStore,
    required this.workspaceId,
    required this.objectTypeId,
    required this.objectId,
    required this.mode,
    this.fixedHeight = 96,
    this.masonryFallbackHeight = 160,
    this.imageBuilder,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int workspaceId;
  final int objectTypeId;
  final int objectId;
  final GalleryViewMode mode;
  final double fixedHeight;
  final double masonryFallbackHeight;
  final WeblinkGalleryImageBuilder? imageBuilder;

  @override
  State<WeblinkGalleryMedia> createState() => _WeblinkGalleryMediaState();
}

class _WeblinkGalleryMediaState extends State<WeblinkGalleryMedia> {
  late Future<_WeblinkGalleryMediaResolution> _resolution;

  @override
  void initState() {
    super.initState();
    _resolution = _resolve();
  }

  @override
  void didUpdateWidget(covariant WeblinkGalleryMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.objectId != widget.objectId) {
      _resolution = _resolve();
    }
  }

  Future<_WeblinkGalleryMediaResolution> _resolve() async {
    if (widget.workspaceId <= 0 ||
        widget.objectTypeId <= 0 ||
        widget.objectId <= 0) {
      return const _WeblinkGalleryMediaResolution(
        kind: _GalleryMediaKind.unsupported,
      );
    }

    final systemObjects = SystemObjectStore(
      database: widget.database,
      objectStore: widget.objectStore,
    );
    final weblinkType = await systemObjects.getSystemObjectType(
      workspaceId: widget.workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    if (weblinkType?.id == widget.objectTypeId) {
      final visual = await WeblinkVisualResolver(widget.objectStore)
          .resolveManagedRepresentative(
        weblinkObjectTypeId: widget.objectTypeId,
        weblinkObjectId: widget.objectId,
      );
      return _WeblinkGalleryMediaResolution(
        kind: _GalleryMediaKind.weblink,
        visual: visual,
      );
    }

    final imageType = await systemObjects.getSystemObjectType(
      workspaceId: widget.workspaceId,
      systemKey: ImageObjectService.systemKey,
    );
    if (imageType?.id == widget.objectTypeId) {
      return const _WeblinkGalleryMediaResolution(
        kind: _GalleryMediaKind.image,
      );
    }

    return const _WeblinkGalleryMediaResolution(
      kind: _GalleryMediaKind.unsupported,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WeblinkGalleryMediaResolution>(
      future: _resolution,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null ||
            resolved.kind == _GalleryMediaKind.unsupported) {
          return const SizedBox.shrink();
        }

        if (resolved.kind == _GalleryMediaKind.image) {
          return ImageGalleryMedia(
            database: widget.database,
            objectStore: widget.objectStore,
            workspaceId: widget.workspaceId,
            objectTypeId: widget.objectTypeId,
            objectId: widget.objectId,
            mode: widget.mode,
            imageBuilder: widget.imageBuilder == null
                ? null
                : (context, filePath) => widget.imageBuilder!(
                      context,
                      filePath,
                      () => _placeholder(context),
                    ),
          );
        }

        final visual = resolved.visual;
        final child = visual == null
            ? _placeholder(context)
            : _image(context, visual.filePath);
        return WeblinkGalleryMediaFrame(
          objectId: widget.objectId,
          mode: widget.mode,
          aspectRatio: visual?.aspectRatio,
          fixedHeight: widget.fixedHeight,
          masonryFallbackHeight: widget.masonryFallbackHeight,
          child: child,
        );
      },
    );
  }

  Widget _image(BuildContext context, String filePath) {
    final custom = widget.imageBuilder;
    if (custom != null) {
      return custom(context, filePath, () => _placeholder(context));
    }
    return Image.file(
      File(filePath),
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(context),
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
