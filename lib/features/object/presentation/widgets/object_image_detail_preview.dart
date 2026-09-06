import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/object_store.dart';
import '../../../../services/image_visual_resolver.dart';

/// Read-only managed Image preview for the shared Object detail surface.
///
/// The host is responsible for rendering this only for the canonical system
/// Image ObjectType. File resolution remains delegated to [ImageVisualResolver]
/// so profile-relative paths and persisted pixel geometry follow the same
/// contract as Gallery media.
class ObjectImageDetailPreview extends StatefulWidget {
  const ObjectImageDetailPreview({
    super.key,
    required this.database,
    required this.objectStore,
    required this.objectTypeId,
    required this.objectId,
    this.maxHeight = 480,
    this.imageBuilder,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int objectTypeId;
  final int objectId;
  final double maxHeight;
  final Widget Function(BuildContext context, String filePath)? imageBuilder;

  @override
  State<ObjectImageDetailPreview> createState() =>
      _ObjectImageDetailPreviewState();
}

class _ObjectImageDetailPreviewState extends State<ObjectImageDetailPreview> {
  late Future<ImageManagedVisual?> _visual;

  @override
  void initState() {
    super.initState();
    _visual = _resolve();
  }

  @override
  void didUpdateWidget(covariant ObjectImageDetailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.objectId != widget.objectId) {
      _visual = _resolve();
    }
  }

  Future<ImageManagedVisual?> _resolve() => ImageVisualResolver(
        widget.objectStore,
        pathResolver: widget.database.pathResolver,
      ).resolveManaged(
        imageObjectTypeId: widget.objectTypeId,
        imageObjectId: widget.objectId,
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageManagedVisual?>(
      future: _visual,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _frame(
            context,
            key: ValueKey('object-image-preview-loading-${widget.objectId}'),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final visual = snapshot.data;
        if (visual == null) {
          return _frame(
            context,
            key: ValueKey('object-image-preview-missing-${widget.objectId}'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  '画像ファイルを表示できません',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        final ratio = visual.aspectRatio;
        final child = widget.imageBuilder?.call(context, visual.filePath) ??
            Image.file(
              File(visual.filePath),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );

        return _frame(
          context,
          key: ValueKey('object-image-preview-${widget.objectId}'),
          aspectRatio: ratio,
          child: child,
        );
      },
    );
  }

  Widget _frame(
    BuildContext context, {
    required Key key,
    required Widget child,
    double? aspectRatio,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final framed = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: child,
      ),
    );

    final ratio = aspectRatio;
    if (ratio != null && ratio.isFinite && ratio > 0) {
      return ConstrainedBox(
        key: key,
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: AspectRatio(aspectRatio: ratio, child: framed),
      );
    }

    return SizedBox(
      key: key,
      width: double.infinity,
      height: 220,
      child: framed,
    );
  }
}
