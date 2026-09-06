import 'package:flutter/material.dart';

enum ObjectImageCropHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Pure normalized geometry used by the free-crop presentation surface.
///
/// Coordinates are always kept inside the unit square so presentation never
/// needs to know source pixel dimensions. The canonical edit service later maps
/// the normalized rectangle onto the managed image bytes after re-checking file
/// ownership.
class ObjectImageCropGeometry {
  const ObjectImageCropGeometry._();

  static const double defaultMinCropSize = 0.06;
  static const Rect defaultRect = Rect.fromLTWH(0.08, 0.08, 0.84, 0.84);

  static Rect normalize(
    Rect rect, {
    double minCropSize = defaultMinCropSize,
  }) {
    final minSize = minCropSize.clamp(0.001, 1.0).toDouble();
    if (!_isFinite(rect)) return _defaultFor(minSize);

    var left = rect.left.clamp(0.0, 1.0).toDouble();
    var top = rect.top.clamp(0.0, 1.0).toDouble();
    var right = rect.right.clamp(0.0, 1.0).toDouble();
    var bottom = rect.bottom.clamp(0.0, 1.0).toDouble();
    if (right <= left || bottom <= top) return _defaultFor(minSize);

    if (right - left < minSize) {
      final center = (left + right) / 2;
      left = (center - minSize / 2).clamp(0.0, 1.0 - minSize).toDouble();
      right = left + minSize;
    }
    if (bottom - top < minSize) {
      final center = (top + bottom) / 2;
      top = (center - minSize / 2).clamp(0.0, 1.0 - minSize).toDouble();
      bottom = top + minSize;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Rect move(
    Rect rect,
    Offset delta,
    Size viewport, {
    double minCropSize = defaultMinCropSize,
  }) {
    final current = normalize(rect, minCropSize: minCropSize);
    if (!_usableViewport(viewport)) return current;

    final dx = delta.dx / viewport.width;
    final dy = delta.dy / viewport.height;
    final left = (current.left + dx)
        .clamp(0.0, 1.0 - current.width)
        .toDouble();
    final top = (current.top + dy)
        .clamp(0.0, 1.0 - current.height)
        .toDouble();
    return Rect.fromLTWH(left, top, current.width, current.height);
  }

  static Rect resize(
    Rect rect,
    ObjectImageCropHandle handle,
    Offset delta,
    Size viewport, {
    double minCropSize = defaultMinCropSize,
  }) {
    final current = normalize(rect, minCropSize: minCropSize);
    if (!_usableViewport(viewport)) return current;

    final minSize = minCropSize.clamp(0.001, 1.0).toDouble();
    final dx = delta.dx / viewport.width;
    final dy = delta.dy / viewport.height;
    var left = current.left;
    var top = current.top;
    var right = current.right;
    var bottom = current.bottom;

    switch (handle) {
      case ObjectImageCropHandle.topLeft:
        left = (left + dx).clamp(0.0, right - minSize).toDouble();
        top = (top + dy).clamp(0.0, bottom - minSize).toDouble();
      case ObjectImageCropHandle.topRight:
        right = (right + dx).clamp(left + minSize, 1.0).toDouble();
        top = (top + dy).clamp(0.0, bottom - minSize).toDouble();
      case ObjectImageCropHandle.bottomLeft:
        left = (left + dx).clamp(0.0, right - minSize).toDouble();
        bottom = (bottom + dy).clamp(top + minSize, 1.0).toDouble();
      case ObjectImageCropHandle.bottomRight:
        right = (right + dx).clamp(left + minSize, 1.0).toDouble();
        bottom = (bottom + dy).clamp(top + minSize, 1.0).toDouble();
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Rect _defaultFor(double minSize) {
    if (minSize >= 0.84) {
      final inset = (1.0 - minSize) / 2;
      return Rect.fromLTWH(inset, inset, minSize, minSize);
    }
    return defaultRect;
  }

  static bool _isFinite(Rect rect) =>
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;

  static bool _usableViewport(Size viewport) =>
      viewport.width.isFinite &&
      viewport.height.isFinite &&
      viewport.width > 0 &&
      viewport.height > 0;
}

/// Interactive free-crop overlay that only edits a normalized [Rect].
///
/// The child is read-only presentation. Drag the crop frame to move it or one
/// of the four corner handles to resize it freely. No file path or image bytes
/// are mutated by this widget.
class ObjectImageCropSelector extends StatefulWidget {
  const ObjectImageCropSelector({
    super.key,
    required this.child,
    this.initialRect = ObjectImageCropGeometry.defaultRect,
    this.minCropSize = ObjectImageCropGeometry.defaultMinCropSize,
    this.onChanged,
  });

  final Widget child;
  final Rect initialRect;
  final double minCropSize;
  final ValueChanged<Rect>? onChanged;

  @override
  State<ObjectImageCropSelector> createState() => _ObjectImageCropSelectorState();
}

class _ObjectImageCropSelectorState extends State<ObjectImageCropSelector> {
  static const double _handleSize = 24;
  late Rect _rect;

  @override
  void initState() {
    super.initState();
    _rect = ObjectImageCropGeometry.normalize(
      widget.initialRect,
      minCropSize: widget.minCropSize,
    );
  }

  @override
  void didUpdateWidget(covariant ObjectImageCropSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRect != widget.initialRect ||
        oldWidget.minCropSize != widget.minCropSize) {
      _rect = ObjectImageCropGeometry.normalize(
        widget.initialRect,
        minCropSize: widget.minCropSize,
      );
    }
  }

  void _setRect(Rect value) {
    final next = ObjectImageCropGeometry.normalize(
      value,
      minCropSize: widget.minCropSize,
    );
    setState(() => _rect = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!size.width.isFinite ||
            !size.height.isFinite ||
            size.width <= 0 ||
            size.height <= 0) {
          return const SizedBox.shrink();
        }

        final crop = Rect.fromLTRB(
          _rect.left * size.width,
          _rect.top * size.height,
          _rect.right * size.width,
          _rect.bottom * size.height,
        );
        final scheme = Theme.of(context).colorScheme;
        final dim = Colors.black.withValues(alpha: 0.42);

        return Stack(
          key: const ValueKey('object-image-free-crop-selector'),
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: crop.top,
              child: ColoredBox(color: dim),
            ),
            Positioned(
              left: 0,
              top: crop.bottom,
              right: 0,
              bottom: 0,
              child: ColoredBox(color: dim),
            ),
            Positioned(
              left: 0,
              top: crop.top,
              width: crop.left,
              height: crop.height,
              child: ColoredBox(color: dim),
            ),
            Positioned(
              left: crop.right,
              top: crop.top,
              right: 0,
              height: crop.height,
              child: ColoredBox(color: dim),
            ),
            Positioned.fromRect(
              rect: crop,
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: GestureDetector(
                  key: const ValueKey('object-image-free-crop-frame'),
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) => _setRect(
                    ObjectImageCropGeometry.move(
                      _rect,
                      details.delta,
                      size,
                      minCropSize: widget.minCropSize,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ),
            _handle(
              handle: ObjectImageCropHandle.topLeft,
              point: crop.topLeft,
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              size: size,
              color: scheme.primary,
            ),
            _handle(
              handle: ObjectImageCropHandle.topRight,
              point: crop.topRight,
              cursor: SystemMouseCursors.resizeUpRightDownLeft,
              size: size,
              color: scheme.primary,
            ),
            _handle(
              handle: ObjectImageCropHandle.bottomLeft,
              point: crop.bottomLeft,
              cursor: SystemMouseCursors.resizeUpRightDownLeft,
              size: size,
              color: scheme.primary,
            ),
            _handle(
              handle: ObjectImageCropHandle.bottomRight,
              point: crop.bottomRight,
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              size: size,
              color: scheme.primary,
            ),
          ],
        );
      },
    );
  }

  Widget _handle({
    required ObjectImageCropHandle handle,
    required Offset point,
    required MouseCursor cursor,
    required Size size,
    required Color color,
  }) {
    final name = switch (handle) {
      ObjectImageCropHandle.topLeft => 'top-left',
      ObjectImageCropHandle.topRight => 'top-right',
      ObjectImageCropHandle.bottomLeft => 'bottom-left',
      ObjectImageCropHandle.bottomRight => 'bottom-right',
    };
    return Positioned(
      left: point.dx - _handleSize / 2,
      top: point.dy - _handleSize / 2,
      width: _handleSize,
      height: _handleSize,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          key: ValueKey('object-image-free-crop-handle-$name'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => _setRect(
            ObjectImageCropGeometry.resize(
              _rect,
              handle,
              details.delta,
              size,
              minCropSize: widget.minCropSize,
            ),
          ),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const SizedBox.square(dimension: 12),
            ),
          ),
        ),
      ),
    );
  }
}
