import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'object_image_crop_selector.dart';

/// Pure normalized geometry for moving/zooming the image beneath a fixed crop
/// frame.
///
/// The returned rectangle always describes the source region that should be
/// passed to the canonical Image edit boundary. Presentation can therefore
/// offer legacy-style pan/zoom without exposing image bytes or file paths.
class ObjectImageCropPanZoomGeometry {
  const ObjectImageCropPanZoomGeometry._();

  static Rect panSource(
    Rect sourceRect,
    Rect frameRect,
    Offset delta,
    Size viewport, {
    double minCropSize = ObjectImageCropGeometry.defaultMinCropSize,
  }) {
    final source = ObjectImageCropGeometry.normalize(
      sourceRect,
      minCropSize: minCropSize,
    );
    final frame = ObjectImageCropGeometry.normalize(
      frameRect,
      minCropSize: minCropSize,
    );
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

  static Rect zoomSource(
    Rect sourceRect,
    double scrollDeltaY, {
    double minCropSize = ObjectImageCropGeometry.defaultMinCropSize,
  }) {
    final source = ObjectImageCropGeometry.normalize(
      sourceRect,
      minCropSize: minCropSize,
    );
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

  static bool _usableViewport(Size viewport) =>
      viewport.width.isFinite &&
      viewport.height.isFinite &&
      viewport.width > 0 &&
      viewport.height > 0;
}

/// Keeps the visible crop frame fixed while the image is dragged or zoomed
/// underneath it.
///
/// This is presentation-only. It emits a normalized source [Rect] and never
/// receives or mutates image bytes/file paths.
class ObjectImageCropPanZoomSelector extends StatefulWidget {
  const ObjectImageCropPanZoomSelector({
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
  State<ObjectImageCropPanZoomSelector> createState() =>
      _ObjectImageCropPanZoomSelectorState();
}

class _ObjectImageCropPanZoomSelectorState
    extends State<ObjectImageCropPanZoomSelector> {
  late Rect _sourceRect;
  late Rect _frameRect;

  @override
  void initState() {
    super.initState();
    _reset(widget.initialRect);
  }

  @override
  void didUpdateWidget(covariant ObjectImageCropPanZoomSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRect != widget.initialRect ||
        oldWidget.minCropSize != widget.minCropSize) {
      _reset(widget.initialRect);
    }
  }

  void _reset(Rect rect) {
    final normalized = ObjectImageCropGeometry.normalize(
      rect,
      minCropSize: widget.minCropSize,
    );
    _sourceRect = normalized;
    _frameRect = normalized;
  }

  void _setSourceRect(Rect value) {
    final next = ObjectImageCropGeometry.normalize(
      value,
      minCropSize: widget.minCropSize,
    );
    setState(() => _sourceRect = next);
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

        final frame = Rect.fromLTRB(
          _frameRect.left * size.width,
          _frameRect.top * size.height,
          _frameRect.right * size.width,
          _frameRect.bottom * size.height,
        );
        final scale = _frameRect.width / _sourceRect.width;
        final translate = Offset(
          (_frameRect.left - _sourceRect.left * scale) * size.width,
          (_frameRect.top - _sourceRect.top * scale) * size.height,
        );
        final scheme = Theme.of(context).colorScheme;
        final dim = Colors.black.withValues(alpha: 0.42);

        return Stack(
          key: const ValueKey('object-image-free-crop-pan-zoom-selector'),
          children: [
            Positioned.fill(
              child: ClipRect(
                child: Transform.translate(
                  offset: translate,
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scale: scale,
                    child: widget.child,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: frame.top,
              child: ColoredBox(color: dim),
            ),
            Positioned(
              left: 0,
              top: frame.bottom,
              right: 0,
              bottom: 0,
              child: ColoredBox(color: dim),
            ),
            Positioned(
              left: 0,
              top: frame.top,
              width: frame.left,
              height: frame.height,
              child: ColoredBox(color: dim),
            ),
            Positioned(
              left: frame.right,
              top: frame.top,
              right: 0,
              height: frame.height,
              child: ColoredBox(color: dim),
            ),
            Positioned.fromRect(
              rect: frame,
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _setSourceRect(
                      ObjectImageCropPanZoomGeometry.zoomSource(
                        _sourceRect,
                        event.scrollDelta.dy,
                        minCropSize: widget.minCropSize,
                      ),
                    );
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: GestureDetector(
                    key: const ValueKey('object-image-free-crop-pan-zoom-frame'),
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) => _setSourceRect(
                      ObjectImageCropPanZoomGeometry.panSource(
                        _sourceRect,
                        _frameRect,
                        details.delta,
                        size,
                        minCropSize: widget.minCropSize,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                      child: const Center(
                        child: IgnorePointer(
                          child: Icon(
                            Icons.open_with,
                            color: Colors.white70,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
