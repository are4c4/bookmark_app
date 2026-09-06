import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum ObjectImageCropHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

enum ObjectImageCropInteractionMode {
  adjustFrame,
  panZoomImage,
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
      case ObjectImageCropHandle.top:
        top = (top + dy).clamp(0.0, bottom - minSize).toDouble();
      case ObjectImageCropHandle.topRight:
        right = (right + dx).clamp(left + minSize, 1.0).toDouble();
        top = (top + dy).clamp(0.0, bottom - minSize).toDouble();
      case ObjectImageCropHandle.right:
        right = (right + dx).clamp(left + minSize, 1.0).toDouble();
      case ObjectImageCropHandle.bottomRight:
        right = (right + dx).clamp(left + minSize, 1.0).toDouble();
        bottom = (bottom + dy).clamp(top + minSize, 1.0).toDouble();
      case ObjectImageCropHandle.bottom:
        bottom = (bottom + dy).clamp(top + minSize, 1.0).toDouble();
      case ObjectImageCropHandle.bottomLeft:
        left = (left + dx).clamp(0.0, right - minSize).toDouble();
        bottom = (bottom + dy).clamp(top + minSize, 1.0).toDouble();
      case ObjectImageCropHandle.left:
        left = (left + dx).clamp(0.0, right - minSize).toDouble();
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Moves the source region opposite the image drag while a crop frame stays
  /// fixed on screen.
  static Rect panSource(
    Rect sourceRect,
    Rect frameRect,
    Offset delta,
    Size viewport, {
    double minCropSize = defaultMinCropSize,
  }) {
    final source = normalize(sourceRect, minCropSize: minCropSize);
    final frame = normalize(frameRect, minCropSize: minCropSize);
    if (!_usableViewport(viewport)) return source;

    final scale = frame.width / source.width;
    if (!scale.isFinite || scale <= 0) return source;

    final dx = -delta.dx / (viewport.width * scale);
    final dy = -delta.dy / (viewport.height * scale);
    final left = (source.left + dx)
        .clamp(0.0, 1.0 - source.width)
        .toDouble();
    final top = (source.top + dy)
        .clamp(0.0, 1.0 - source.height)
        .toDouble();
    return Rect.fromLTWH(left, top, source.width, source.height);
  }

  /// Zooms a source region around its center while preserving its aspect ratio.
  static Rect zoomSource(
    Rect sourceRect,
    double scrollDeltaY, {
    double minCropSize = defaultMinCropSize,
  }) {
    final source = normalize(sourceRect, minCropSize: minCropSize);
    if (!scrollDeltaY.isFinite) return source;

    final minSize = minCropSize.clamp(0.001, 1.0).toDouble();
    final requestedScale = math.exp(scrollDeltaY * 0.0015).clamp(0.82, 1.22);
    final minScale = math.max(
      minSize / source.width,
      minSize / source.height,
    );
    final maxScale = math.min(
      1.0 / source.width,
      1.0 / source.height,
    );
    final scale = requestedScale.clamp(minScale, maxScale).toDouble();

    final width = source.width * scale;
    final height = source.height * scale;
    final center = source.center;
    final left = (center.dx - width / 2)
        .clamp(0.0, 1.0 - width)
        .toDouble();
    final top = (center.dy - height / 2)
        .clamp(0.0, 1.0 - height)
        .toDouble();
    return Rect.fromLTWH(left, top, width, height);
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
/// In [ObjectImageCropInteractionMode.adjustFrame], drag the crop frame or its
/// corner/edge handles. In [ObjectImageCropInteractionMode.panZoomImage], the
/// frame stays fixed while the image is dragged or mouse-wheel zoomed beneath
/// it. No file path or image bytes are mutated by this widget.
class ObjectImageCropSelector extends StatefulWidget {
  const ObjectImageCropSelector({
    super.key,
    required this.child,
    this.initialRect = ObjectImageCropGeometry.defaultRect,
    this.minCropSize = ObjectImageCropGeometry.defaultMinCropSize,
    this.mode = ObjectImageCropInteractionMode.adjustFrame,
    this.onChanged,
  });

  final Widget child;
  final Rect initialRect;
  final double minCropSize;
  final ObjectImageCropInteractionMode mode;
  final ValueChanged<Rect>? onChanged;

  @override
  State<ObjectImageCropSelector> createState() => _ObjectImageCropSelectorState();
}

class _ObjectImageCropSelectorState extends State<ObjectImageCropSelector> {
  static const double _handleSize = 24;
  late Rect _rect;
  late Rect _frameRect;

  @override
  void initState() {
    super.initState();
    _reset(widget.initialRect);
  }

  @override
  void didUpdateWidget(covariant ObjectImageCropSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRect != widget.initialRect ||
        oldWidget.minCropSize != widget.minCropSize) {
      _reset(widget.initialRect);
    } else if (oldWidget.mode != widget.mode) {
      // Entering move-image mode freezes the current visible frame. Returning
      // to frame adjustment makes the current source region the new frame.
      _frameRect = _rect;
    }
  }

  void _reset(Rect value) {
    final next = ObjectImageCropGeometry.normalize(
      value,
      minCropSize: widget.minCropSize,
    );
    _rect = next;
    _frameRect = next;
  }

  void _setRect(Rect value) {
    final next = ObjectImageCropGeometry.normalize(
      value,
      minCropSize: widget.minCropSize,
    );
    setState(() {
      _rect = next;
      if (widget.mode == ObjectImageCropInteractionMode.adjustFrame) {
        _frameRect = next;
      }
    });
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

        final moveImage =
            widget.mode == ObjectImageCropInteractionMode.panZoomImage;
        final frameRect = moveImage ? _frameRect : _rect;
        final crop = Rect.fromLTRB(
          frameRect.left * size.width,
          frameRect.top * size.height,
          frameRect.right * size.width,
          frameRect.bottom * size.height,
        );
        final scheme = Theme.of(context).colorScheme;
        final dim = Colors.black.withValues(alpha: 0.42);

        return Stack(
          key: ValueKey(
            moveImage
                ? 'object-image-free-crop-pan-zoom-selector'
                : 'object-image-free-crop-selector',
          ),
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _imageLayer(size, frameRect)),
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
              child: _frameInteraction(
                size: size,
                scheme: scheme,
                moveImage: moveImage,
              ),
            ),
            if (!moveImage) ...[
              _handle(
                handle: ObjectImageCropHandle.topLeft,
                point: crop.topLeft,
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                size: size,
                color: scheme.primary,
              ),
              _handle(
                handle: ObjectImageCropHandle.top,
                point: Offset(crop.center.dx, crop.top),
                cursor: SystemMouseCursors.resizeUpDown,
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
                handle: ObjectImageCropHandle.right,
                point: Offset(crop.right, crop.center.dy),
                cursor: SystemMouseCursors.resizeLeftRight,
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
              _handle(
                handle: ObjectImageCropHandle.bottom,
                point: Offset(crop.center.dx, crop.bottom),
                cursor: SystemMouseCursors.resizeUpDown,
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
                handle: ObjectImageCropHandle.left,
                point: Offset(crop.left, crop.center.dy),
                cursor: SystemMouseCursors.resizeLeftRight,
                size: size,
                color: scheme.primary,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _imageLayer(Size size, Rect frameRect) {
    if (widget.mode != ObjectImageCropInteractionMode.panZoomImage) {
      return widget.child;
    }
    final scale = frameRect.width / _rect.width;
    final translate = Offset(
      (frameRect.left - _rect.left * scale) * size.width,
      (frameRect.top - _rect.top * scale) * size.height,
    );
    return ClipRect(
      child: Transform.translate(
        offset: translate,
        child: Transform.scale(
          alignment: Alignment.topLeft,
          scale: scale,
          child: widget.child,
        ),
      ),
    );
  }

  Widget _frameInteraction({
    required Size size,
    required ColorScheme scheme,
    required bool moveImage,
  }) {
    final frame = MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        key: ValueKey(
          moveImage
              ? 'object-image-free-crop-pan-zoom-frame'
              : 'object-image-free-crop-frame',
        ),
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) => _setRect(
          moveImage
              ? ObjectImageCropGeometry.panSource(
                  _rect,
                  _frameRect,
                  details.delta,
                  size,
                  minCropSize: widget.minCropSize,
                )
              : ObjectImageCropGeometry.move(
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
          child: moveImage
              ? const Center(
                  child: IgnorePointer(
                    child: Icon(
                      Icons.open_with,
                      color: Colors.white70,
                      size: 30,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
    if (!moveImage) return frame;
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _setRect(
            ObjectImageCropGeometry.zoomSource(
              _rect,
              event.scrollDelta.dy,
              minCropSize: widget.minCropSize,
            ),
          );
        }
      },
      child: frame,
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
      ObjectImageCropHandle.top => 'top',
      ObjectImageCropHandle.topRight => 'top-right',
      ObjectImageCropHandle.right => 'right',
      ObjectImageCropHandle.bottomRight => 'bottom-right',
      ObjectImageCropHandle.bottom => 'bottom',
      ObjectImageCropHandle.bottomLeft => 'bottom-left',
      ObjectImageCropHandle.left => 'left',
    };
    final isEdge = switch (handle) {
      ObjectImageCropHandle.top ||
      ObjectImageCropHandle.right ||
      ObjectImageCropHandle.bottom ||
      ObjectImageCropHandle.left => true,
      _ => false,
    };
    final isHorizontalEdge = handle == ObjectImageCropHandle.top ||
        handle == ObjectImageCropHandle.bottom;

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
                shape: isEdge ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isEdge ? BorderRadius.circular(2) : null,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: SizedBox(
                width: isEdge ? (isHorizontalEdge ? 14 : 8) : 12,
                height: isEdge ? (isHorizontalEdge ? 8 : 14) : 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
