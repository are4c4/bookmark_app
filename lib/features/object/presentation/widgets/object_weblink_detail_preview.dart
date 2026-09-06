import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/object_store.dart';
import '../../../../services/weblink_visual_resolver.dart';

typedef ObjectWeblinkDetailVisualResolver = Future<WeblinkManagedVisual?> Function({
  required int objectTypeId,
  required int objectId,
});

/// Read-only managed Representative Image preview for a canonical Weblink.
///
/// The widget consumes the existing [WeblinkVisualResolver] and never ensures
/// schema or mutates Relation/Object state. A missing representative image is a
/// normal Weblink state and therefore collapses cleanly instead of presenting a
/// broken-media error.
class ObjectWeblinkDetailPreview extends StatefulWidget {
  const ObjectWeblinkDetailPreview({
    super.key,
    required this.database,
    required this.objectStore,
    required this.objectTypeId,
    required this.objectId,
    this.maxHeight = 360,
    this.visualResolver,
    this.imageBuilder,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int objectTypeId;
  final int objectId;
  final double maxHeight;
  final ObjectWeblinkDetailVisualResolver? visualResolver;
  final Widget Function(BuildContext context, String filePath)? imageBuilder;

  @override
  State<ObjectWeblinkDetailPreview> createState() =>
      _ObjectWeblinkDetailPreviewState();
}

class _ObjectWeblinkDetailPreviewState
    extends State<ObjectWeblinkDetailPreview> {
  late Future<WeblinkManagedVisual?> _visual;

  @override
  void initState() {
    super.initState();
    _visual = _resolve();
  }

  @override
  void didUpdateWidget(covariant ObjectWeblinkDetailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.objectId != widget.objectId ||
        oldWidget.visualResolver != widget.visualResolver) {
      _visual = _resolve();
    }
  }

  Future<WeblinkManagedVisual?> _resolve() {
    final custom = widget.visualResolver;
    if (custom != null) {
      return custom(
        objectTypeId: widget.objectTypeId,
        objectId: widget.objectId,
      );
    }
    return WeblinkVisualResolver(
      widget.objectStore,
      pathResolver: widget.database.pathResolver,
    ).resolveManagedRepresentative(
      weblinkObjectTypeId: widget.objectTypeId,
      weblinkObjectId: widget.objectId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeblinkManagedVisual?>(
      future: _visual,
      builder: (context, snapshot) => ObjectWeblinkDetailPreviewContent(
        objectId: widget.objectId,
        isLoading: snapshot.connectionState != ConnectionState.done,
        visual: snapshot.data,
        maxHeight: widget.maxHeight,
        imageBuilder: widget.imageBuilder,
      ),
    );
  }
}

/// Pure presentation layer for [ObjectWeblinkDetailPreview].
class ObjectWeblinkDetailPreviewContent extends StatelessWidget {
  const ObjectWeblinkDetailPreviewContent({
    super.key,
    required this.objectId,
    required this.isLoading,
    required this.visual,
    this.maxHeight = 360,
    this.imageBuilder,
  });

  final int objectId;
  final bool isLoading;
  final WeblinkManagedVisual? visual;
  final double maxHeight;
  final Widget Function(BuildContext context, String filePath)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        key: ValueKey('object-weblink-preview-loading-$objectId'),
        height: 120,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final resolved = visual;
    if (resolved == null) {
      return SizedBox.shrink(
        key: ValueKey('object-weblink-preview-missing-$objectId'),
      );
    }

    final child = imageBuilder?.call(context, resolved.filePath) ??
        Image.file(
          File(resolved.filePath),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context),
        );
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

    final ratio = resolved.aspectRatio;
    if (ratio != null && ratio.isFinite && ratio > 0) {
      return ConstrainedBox(
        key: ValueKey('object-weblink-preview-$objectId'),
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(aspectRatio: ratio, child: framed),
      );
    }

    return SizedBox(
      key: ValueKey('object-weblink-preview-$objectId'),
      width: double.infinity,
      height: maxHeight.clamp(120.0, 240.0).toDouble(),
      child: framed,
    );
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: scheme.onSurfaceVariant.withValues(alpha: .65),
        ),
      ),
    );
  }
}
