import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/image_object_service.dart';
import '../../../../data/object_store.dart';
import '../../../../data/system_object_store.dart';
import '../../../../services/image_visual_resolver.dart';
import 'object_gallery_view.dart';

/// Read-only managed media presentation for the canonical system Image type.
///
/// The widget verifies the system Image identity before resolving the managed
/// file. Fixed Gallery keeps a stable media band; masonry uses persisted Pixel
/// width/height geometry without decoding the image bytes for layout.
class ImageGalleryMedia extends StatefulWidget {
  const ImageGalleryMedia({
    super.key,
    required this.database,
    required this.objectStore,
    required this.workspaceId,
    required this.objectTypeId,
    required this.objectId,
    required this.mode,
    this.imageBuilder,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int workspaceId;
  final int objectTypeId;
  final int objectId;
  final GalleryViewMode mode;
  final Widget Function(BuildContext context, String filePath)? imageBuilder;

  @override
  State<ImageGalleryMedia> createState() => _ImageGalleryMediaState();
}

class _ImageGalleryMediaState extends State<ImageGalleryMedia> {
  late Future<ImageManagedVisual?> _visual;

  @override
  void initState() {
    super.initState();
    _visual = _resolve();
  }

  @override
  void didUpdateWidget(covariant ImageGalleryMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.objectId != widget.objectId) {
      _visual = _resolve();
    }
  }

  Future<ImageManagedVisual?> _resolve() async {
    if (widget.workspaceId <= 0 ||
        widget.objectTypeId <= 0 ||
        widget.objectId <= 0) {
      return null;
    }
    final registry = SystemObjectStore(
      database: widget.database,
      objectStore: widget.objectStore,
    );
    final imageType = await registry.getSystemObjectType(
      workspaceId: widget.workspaceId,
      systemKey: ImageObjectService.systemKey,
    );
    if (imageType == null || imageType.id != widget.objectTypeId) return null;
    return ImageVisualResolver(widget.objectStore).resolveManaged(
      imageObjectTypeId: widget.objectTypeId,
      imageObjectId: widget.objectId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageManagedVisual?>(
      future: _visual,
      builder: (context, snapshot) {
        final visual = snapshot.data;
        final child = visual == null
            ? _placeholder(context)
            : _image(context, visual.filePath);
        return ImageGalleryMediaFrame(
          objectId: widget.objectId,
          mode: widget.mode,
          aspectRatio: visual?.aspectRatio,
          child: child,
        );
      },
    );
  }

  Widget _image(BuildContext context, String path) {
    final builder = widget.imageBuilder;
    if (builder != null) return builder(context, path);
    return Image.file(
      File(path),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .55),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 26,
          color: scheme.onSurfaceVariant.withValues(alpha: .6),
        ),
      ),
    );
  }
}

class ImageGalleryMediaFrame extends StatelessWidget {
  const ImageGalleryMediaFrame({
    super.key,
    required this.objectId,
    required this.mode,
    required this.child,
    this.aspectRatio,
    this.fixedHeight = 96,
    this.fallbackHeight = 160,
  });

  final int objectId;
  final GalleryViewMode mode;
  final Widget child;
  final double? aspectRatio;
  final double fixedHeight;
  final double fallbackHeight;

  @override
  Widget build(BuildContext context) {
    if (mode == GalleryViewMode.fixed) {
      return SizedBox(
        key: ValueKey('image-gallery-media-fixed-$objectId'),
        height: fixedHeight,
        width: double.infinity,
        child: child,
      );
    }

    final ratio = aspectRatio;
    if (ratio != null && ratio.isFinite && ratio > 0) {
      return AspectRatio(
        key: ValueKey('image-gallery-media-ratio-$objectId'),
        aspectRatio: ratio,
        child: child,
      );
    }

    return SizedBox(
      key: ValueKey('image-gallery-media-fallback-$objectId'),
      height: fallbackHeight,
      width: double.infinity,
      child: child,
    );
  }
}
