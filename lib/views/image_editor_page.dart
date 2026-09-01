import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/image_edit_service.dart';

class ImageEditorPage extends StatefulWidget {
  const ImageEditorPage({super.key, required this.path});

  final String path;

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  static const _service = ImageEditService();
  static const double _minCropSize = 0.06;
  static const double _edgeHitSize = 18;

  int _quarterTurns = 0;
  bool _flipHorizontal = false;
  bool _saving = false;
  bool _hasBackup = false;
  bool _moveImageMode = false;
  Size? _imageSize;
  Rect? _cropRect;
  Rect? _displayFrameRect;
  String _cropMode = 'none';

  static const _cropOptions = <String, double?>{
    'なし': null,
    '自由': -1,
    '1 : 1': 1,
    '4 : 3': 4 / 3,
    '3 : 4': 3 / 4,
    '16 : 9': 16 / 9,
    '9 : 16': 9 / 16,
  };

  @override
  void initState() {
    super.initState();
    _loadBackupState();
    _loadImageSize();
  }

  Future<void> _loadBackupState() async {
    final value = await _service.hasBackup(widget.path);
    if (mounted) setState(() => _hasBackup = value);
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      if (mounted) setState(() => _imageSize = size);
    } catch (_) {
      // Image.file shows its own error state when decoding fails.
    }
  }

  Size? get _transformedImageSize {
    final size = _imageSize;
    if (size == null) return null;
    return _quarterTurns.isOdd
        ? Size(size.height, size.width)
        : size;
  }

  void _setCropMode(String label) {
    final value = _cropOptions[label];
    setState(() {
      _cropMode = label;
      _moveImageMode = false;
      _displayFrameRect = null;
      if (label == 'none' || label == 'なし') {
        _cropRect = null;
      } else if (label == '自由') {
        _cropRect ??= const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
      } else if (value != null && value > 0) {
        _cropRect = _centeredCropRect(value);
      }
    });
  }

  Rect _centeredCropRect(double ratio) {
    final size = _transformedImageSize;
    if (size == null || size.width <= 0 || size.height <= 0) {
      return const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
    }
    final imageRatio = size.width / size.height;
    if (imageRatio > ratio) {
      final normalizedWidth = ratio / imageRatio;
      return Rect.fromLTWH((1 - normalizedWidth) / 2, 0, normalizedWidth, 1);
    }
    final normalizedHeight = imageRatio / ratio;
    return Rect.fromLTWH(0, (1 - normalizedHeight) / 2, 1, normalizedHeight);
  }

  void _moveCrop(Offset delta, Size displaySize) {
    final rect = _cropRect;
    if (rect == null || displaySize.width <= 0 || displaySize.height <= 0) return;
    final dx = delta.dx / displaySize.width;
    final dy = delta.dy / displaySize.height;
    final width = rect.width;
    final height = rect.height;
    final left = (rect.left + dx).clamp(0.0, 1.0 - width).toDouble();
    final top = (rect.top + dy).clamp(0.0, 1.0 - height).toDouble();
    setState(() => _cropRect = Rect.fromLTWH(left, top, width, height));
  }

  void _resizeCrop(String handle, Offset delta, Size displaySize) {
    final rect = _cropRect;
    if (rect == null || displaySize.width <= 0 || displaySize.height <= 0) return;
    final dx = delta.dx / displaySize.width;
    final dy = delta.dy / displaySize.height;
    var left = rect.left;
    var top = rect.top;
    var right = rect.right;
    var bottom = rect.bottom;

    if (handle.contains('l')) {
      left = (left + dx).clamp(0.0, right - _minCropSize).toDouble();
    }
    if (handle.contains('r')) {
      right = (right + dx).clamp(left + _minCropSize, 1.0).toDouble();
    }
    if (handle.contains('t')) {
      top = (top + dy).clamp(0.0, bottom - _minCropSize).toDouble();
    }
    if (handle.contains('b')) {
      bottom = (bottom + dy).clamp(top + _minCropSize, 1.0).toDouble();
    }

    setState(() {
      _cropMode = '自由';
      _cropRect = Rect.fromLTRB(left, top, right, bottom);
    });
  }

  void _toggleMoveImageMode() {
    final crop = _cropRect;
    if (crop == null) return;
    setState(() {
      _moveImageMode = !_moveImageMode;
      if (_moveImageMode) {
        _displayFrameRect = crop;
      } else {
        _displayFrameRect = null;
      }
    });
  }

  void _moveImageUnderFrame(Offset delta, Size displaySize) {
    final source = _cropRect;
    final frame = _displayFrameRect;
    if (source == null || frame == null) return;
    final scale = frame.width / source.width;
    if (scale <= 0) return;

    final dx = -delta.dx / (displaySize.width * scale);
    final dy = -delta.dy / (displaySize.height * scale);
    final left = (source.left + dx)
        .clamp(0.0, 1.0 - source.width)
        .toDouble();
    final top = (source.top + dy)
        .clamp(0.0, 1.0 - source.height)
        .toDouble();
    setState(() {
      _cropRect = Rect.fromLTWH(left, top, source.width, source.height);
    });
  }

  void _zoomImage(double scrollDeltaY) {
    final source = _cropRect;
    final frame = _displayFrameRect;
    if (source == null || frame == null) return;

    final factor = math.exp(scrollDeltaY * 0.0015).clamp(0.82, 1.22);
    final newWidth = (source.width * factor)
        .clamp(_minCropSize, math.min(1.0, source.width * 4))
        .toDouble();
    final aspect = source.height / source.width;
    var newHeight = newWidth * aspect;
    var adjustedWidth = newWidth;
    if (newHeight > 1.0) {
      newHeight = 1.0;
      adjustedWidth = newHeight / aspect;
    }

    final center = source.center;
    var left = center.dx - adjustedWidth / 2;
    var top = center.dy - newHeight / 2;
    left = left.clamp(0.0, 1.0 - adjustedWidth).toDouble();
    top = top.clamp(0.0, 1.0 - newHeight).toDouble();

    setState(() {
      _cropRect = Rect.fromLTWH(left, top, adjustedWidth, newHeight);
    });
  }

  Matrix4 _imageTransform(Size displaySize) {
    final source = _cropRect;
    final frame = _displayFrameRect;
    if (!_moveImageMode || source == null || frame == null) {
      return Matrix4.identity();
    }
    final scale = frame.width / source.width;
    final tx = (frame.left - source.left * scale) * displaySize.width;
    final ty = (frame.top - source.top * scale) * displaySize.height;
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
  }

  Widget _imageWidget({Matrix4? transform}) {
    Widget image = Image.file(
      File(widget.path),
      fit: BoxFit.fill,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_outlined, size: 48),
      ),
    );
    image = RotatedBox(quarterTurns: _quarterTurns, child: image);
    if (_flipHorizontal) {
      image = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: image,
      );
    }
    if (transform != null) {
      image = Transform(
        alignment: Alignment.topLeft,
        transform: transform,
        child: image,
      );
    }
    return image;
  }

  Widget _edgeHandle(
    String handle,
    Alignment alignment,
    Size displaySize, {
    required bool horizontal,
  }) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) =>
            _resizeCrop(handle, details.delta, displaySize),
        child: SizedBox(
          width: horizontal ? 54 : _edgeHitSize,
          height: horizontal ? _edgeHitSize : 54,
          child: Center(
            child: Container(
              width: horizontal ? 34 : 3,
              height: horizontal ? 3 : 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(blurRadius: 3, color: Colors.black45),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cropOverlay(Size displaySize) {
    final sourceRect = _cropRect;
    if (sourceRect == null) return const SizedBox.shrink();
    final visibleRect = _moveImageMode && _displayFrameRect != null
        ? _displayFrameRect!
        : sourceRect;
    final pixelRect = Rect.fromLTRB(
      visibleRect.left * displaySize.width,
      visibleRect.top * displaySize.height,
      visibleRect.right * displaySize.width,
      visibleRect.bottom * displaySize.height,
    );

    Widget cornerHandle(String corner, Alignment alignment) => Align(
          alignment: alignment,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _moveImageMode
                ? null
                : (details) =>
                    _resizeCrop(corner, details.delta, displaySize),
            child: const SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(blurRadius: 3, color: Colors.black45)],
                  ),
                  child: SizedBox(width: 12, height: 12),
                ),
              ),
            ),
          ),
        );

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _CropMaskPainter(pixelRect)),
        ),
        Positioned.fromRect(
          rect: pixelRect,
          child: Listener(
            onPointerSignal: _moveImageMode
                ? (event) {
                    if (event is PointerScrollEvent) {
                      _zoomImage(event.scrollDelta.dy);
                    }
                  }
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) => _moveImageMode
                  ? _moveImageUnderFrame(details.delta, displaySize)
                  : _moveCrop(details.delta, displaySize),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                  if (!_moveImageMode) ...[
                    cornerHandle('lt', Alignment.topLeft),
                    cornerHandle('rt', Alignment.topRight),
                    cornerHandle('lb', Alignment.bottomLeft),
                    cornerHandle('rb', Alignment.bottomRight),
                    _edgeHandle(
                      't',
                      Alignment.topCenter,
                      displaySize,
                      horizontal: true,
                    ),
                    _edgeHandle(
                      'b',
                      Alignment.bottomCenter,
                      displaySize,
                      horizontal: true,
                    ),
                    _edgeHandle(
                      'l',
                      Alignment.centerLeft,
                      displaySize,
                      horizontal: false,
                    ),
                    _edgeHandle(
                      'r',
                      Alignment.centerRight,
                      displaySize,
                      horizontal: false,
                    ),
                  ],
                  if (_moveImageMode)
                    const Center(
                      child: IgnorePointer(
                        child: Icon(
                          Icons.open_with,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _preview() {
    final transformedSize = _transformedImageSize;
    if (transformedSize == null) {
      return Center(child: _imageWidget());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = [
          constraints.maxWidth / transformedSize.width,
          constraints.maxHeight / transformedSize.height,
        ].reduce((a, b) => a < b ? a : b);
        final displaySize = Size(
          transformedSize.width * scale,
          transformedSize.height * scale,
        );
        return Center(
          child: ClipRect(
            child: SizedBox(
              width: displaySize.width,
              height: displaySize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _imageWidget(transform: _imageTransform(displaySize)),
                  if (_cropRect != null) _cropOverlay(displaySize),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.apply(
        path: widget.path,
        quarterTurns: _quarterTurns,
        flipHorizontal: _flipHorizontal,
        normalizedCropRect: _cropRect,
      );
      await FileImage(File(widget.path)).evict();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像を編集できませんでした: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restore() async {
    if (!_hasBackup || _saving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('元画像に戻しますか？'),
        content: const Text('最初に編集する前の画像へ戻します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('元に戻す'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await _service.restoreOriginal(widget.path);
      await FileImage(File(widget.path)).evict();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('元画像に戻せませんでした: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _rotate(int delta) {
    setState(() {
      _quarterTurns = (_quarterTurns + delta) % 4;
      _moveImageMode = false;
      _displayFrameRect = null;
      final ratio = _cropOptions[_cropMode];
      if (ratio != null && ratio > 0) {
        _cropRect = _centeredCropRect(ratio);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('画像を編集'),
        actions: [
          if (_hasBackup)
            TextButton.icon(
              onPressed: _saving ? null : _restore,
              icon: const Icon(Icons.restore, size: 17),
              label: const Text('元画像に戻す'),
            ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: scheme.surfaceContainerLowest,
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900, maxHeight: 680),
                child: _preview(),
              ),
            ),
          ),
          Material(
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  IconButton(
                    tooltip: '左へ90°回転',
                    onPressed: () => _rotate(3),
                    icon: const Icon(Icons.rotate_left),
                  ),
                  IconButton(
                    tooltip: '右へ90°回転',
                    onPressed: () => _rotate(1),
                    icon: const Icon(Icons.rotate_right),
                  ),
                  FilterChip(
                    label: const Text('左右反転'),
                    selected: _flipHorizontal,
                    onSelected: (value) => setState(() => _flipHorizontal = value),
                    avatar: const Icon(Icons.flip, size: 17),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'トリミング',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  DropdownButton<String>(
                    value: _cropMode,
                    items: _cropOptions.keys
                        .map(
                          (label) => DropdownMenuItem<String>(
                            value: label == 'なし' ? 'none' : label,
                            child: Text(label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _setCropMode(value);
                    },
                  ),
                  if (_cropRect != null)
                    FilterChip(
                      label: const Text('画像を動かす'),
                      selected: _moveImageMode,
                      onSelected: (_) => _toggleMoveImageMode(),
                      avatar: const Icon(Icons.open_with, size: 17),
                    ),
                  if (_cropRect != null)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _cropMode = '自由';
                        _moveImageMode = false;
                        _displayFrameRect = null;
                        _cropRect = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
                      }),
                      icon: const Icon(Icons.restart_alt, size: 17),
                      label: const Text('枠をリセット'),
                    ),
                  Text(
                    _cropRect == null
                        ? 'JPG / PNG対応'
                        : _moveImageMode
                            ? 'ドラッグで画像移動・ホイールでズーム'
                            : '枠内ドラッグで移動・辺/四隅でサイズ変更',
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CropMaskPainter extends CustomPainter {
  const _CropMaskPainter(this.cropRect);

  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.48);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(cropRect);
    canvas.drawPath(path, paint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(
        Offset(x, cropRect.top),
        Offset(x, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, y),
        Offset(cropRect.right, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
