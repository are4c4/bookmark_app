import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/object_store.dart';
import '../../../../services/image_visual_resolver.dart';
import 'object_image_crop_selector.dart';
import 'object_image_detail_preview.dart';

/// Resolves a canonical managed Image and returns only a normalized crop [Rect].
///
/// This dialog is intentionally read-only with respect to image bytes. The
/// caller must pass the returned rectangle to [CanonicalImageEditService] so
/// ownership and format checks are repeated immediately before mutation.
class ObjectImageFreeCropDialog extends StatefulWidget {
  const ObjectImageFreeCropDialog({
    super.key,
    required this.database,
    required this.objectStore,
    required this.objectTypeId,
    required this.objectId,
    this.visualResolver,
    this.imageBuilder,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int objectTypeId;
  final int objectId;
  final ObjectImagePreviewVisualResolver? visualResolver;
  final Widget Function(BuildContext context, String filePath)? imageBuilder;

  @override
  State<ObjectImageFreeCropDialog> createState() =>
      _ObjectImageFreeCropDialogState();
}

class _ObjectImageFreeCropDialogState extends State<ObjectImageFreeCropDialog> {
  late Future<ImageManagedVisual?> _visual;
  Rect _selection = ObjectImageCropGeometry.defaultRect;

  @override
  void initState() {
    super.initState();
    _visual = _resolveVisual();
  }

  @override
  void didUpdateWidget(covariant ObjectImageFreeCropDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.objectId != widget.objectId ||
        oldWidget.visualResolver != widget.visualResolver) {
      _selection = ObjectImageCropGeometry.defaultRect;
      _visual = _resolveVisual();
    }
  }

  Future<ImageManagedVisual?> _resolveVisual() {
    final custom = widget.visualResolver;
    if (custom != null) {
      return custom(
        objectTypeId: widget.objectTypeId,
        objectId: widget.objectId,
      );
    }
    return ImageVisualResolver(
      widget.objectStore,
      pathResolver: widget.database.pathResolver,
    ).resolveManaged(
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
        final ratio = visual?.aspectRatio;
        final canApply = snapshot.connectionState == ConnectionState.done &&
            visual != null &&
            ratio != null &&
            ratio.isFinite &&
            ratio > 0;

        return AlertDialog(
          title: const Text('自由トリミング'),
          content: _content(
            context,
            loading: snapshot.connectionState != ConnectionState.done,
            visual: visual,
            aspectRatio: ratio,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const ValueKey('object-image-free-crop-apply'),
              onPressed: canApply
                  ? () => Navigator.pop(
                        context,
                        ObjectImageCropGeometry.normalize(_selection),
                      )
                  : null,
              child: const Text('トリミング'),
            ),
          ],
        );
      },
    );
  }

  Widget _content(
    BuildContext context, {
    required bool loading,
    required ImageManagedVisual? visual,
    required double? aspectRatio,
  }) {
    if (loading) {
      return const SizedBox(
        width: 320,
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (visual == null) {
      return const SizedBox(
        width: 320,
        child: Text('画像ファイルを表示できません。'),
      );
    }
    final ratio = aspectRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0) {
      return const SizedBox(
        width: 320,
        child: Text('画像サイズを特定できないため、自由トリミングできません。'),
      );
    }

    final viewport = MediaQuery.sizeOf(context);
    final maxWidth = math.max(220.0, math.min(720.0, viewport.width * 0.72));
    final maxHeight = math.max(180.0, math.min(560.0, viewport.height * 0.60));
    var width = maxWidth;
    var height = width / ratio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio;
    }

    final image = widget.imageBuilder?.call(context, visual.filePath) ??
        Image.file(
          File(visual.filePath),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.fill,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined),
          ),
        );

    return SizedBox(
      key: const ValueKey('object-image-free-crop-surface'),
      width: width,
      height: height,
      child: ObjectImageCropSelector(
        initialRect: _selection,
        onChanged: (value) => _selection = value,
        child: image,
      ),
    );
  }
}
