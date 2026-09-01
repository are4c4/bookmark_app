import 'dart:io';
import 'dart:ui' as ui;

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

  int _quarterTurns = 0;
  bool _flipHorizontal = false;
  bool _saving = false;
  bool _hasBackup = false;
  Size? _imageSize;
  Rect? _cropRect;
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
    final left = (rect.left + dx).clamp(0.0, 1.0 - width);
    final top = (rect.top + dy).clamp(0.0, 1.0 - height);
    setState(() => _cropRect = Rect.fromLTWH(left, top, width, height));
  }

  void _resizeCrop(String corner, Offset delta, Size displaySize) {
    final rect = _cropRect;
    if (rect == null || displaySize.width <= 0 || displaySize.height <= 0) return;
    final dx = delta.dx / displaySize.width;
    final dy = delta.dy / displaySize.height;
    var left = rect.left;
    var top = rect.top;
    var right = rect.right;
    var bottom = rect.bottom;

    if (corner.contains('l')) {
      left = (left + dx).clamp(0.0, right - _minCropSize);
    }
    if (corner.contains('r')) {
      right = (right + dx).clamp(left + _minCropSize, 1.0);
    }
    if (corner.contains('t')) {
      top = (top + dy).clamp(0.0, bottom - _minCropSize);
    }
    if (corner.contains('b')) {
      bottom = (bottom + dy).clamp(top + _minCropSize, 1.0);
    }

    setState(() {
      _cropMode = '自由';
      _cropRect = Rect.fromLTRB(left, top, right, bottom);
    });
  }

  Widget _imageWidget() {
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
    return image;
  }

  Widget _cropOverlay(Size displaySize) {
    final rect = _cropRect;
    if (rect == null) return const SizedBox.shrink();
    final pixelRect = Rect.fromLTRB(
      rect.left * displaySize.width,
      rect.top * displaySize.height,
      rect.right * displaySize.width,
      rect.bottom * displaySize.height,
    );

    Widget handle(String corner, Alignment alignment) => Align(
          alignment: alignment,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) =>
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
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) => _moveCrop(details.delta, displaySize),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
                handle('lt', Alignment.topLeft),
                handle('rt', Alignment.topRight),
                handle('lb', Alignment.bottomLeft),
                handle('rb', Alignment.bottomRight),
              ],
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
          child: SizedBox(
            width: displaySize.width,
            height: displaySize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _imageWidget(),
                if (_cropRect != null) _cropOverlay(displaySize),
              ],
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
              child: Row(
                children: [
                  IconButton(
                    tooltip: '左へ90°回転',
                    onPressed: () => setState(() {
                      _quarterTurns = (_quarterTurns + 3) % 4;
                      final ratio = _cropOptions[_cropMode];
                      if (ratio != null && ratio > 0) {
                        _cropRect = _centeredCropRect(ratio);
                      }
                    }),
                    icon: const Icon(Icons.rotate_left),
                  ),
                  IconButton(
                    tooltip: '右へ90°回転',
                    onPressed: () => setState(() {
                      _quarterTurns = (_quarterTurns + 1) % 4;
                      final ratio = _cropOptions[_cropMode];
                      if (ratio != null && ratio > 0) {
                        _cropRect = _centeredCropRect(ratio);
                      }
                    }),
                    icon: const Icon(Icons.rotate_right),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('左右反転'),
                    selected: _flipHorizontal,
                    onSelected: (value) => setState(() => _flipHorizontal = value),
                    avatar: const Icon(Icons.flip, size: 17),
                  ),
                  const SizedBox(width: 18),
                  const Text(
                    'トリミング',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
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
                  if (_cropRect != null) ...[
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _cropMode = '自由';
                        _cropRect = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
                      }),
                      icon: const Icon(Icons.restart_alt, size: 17),
                      label: const Text('枠をリセット'),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _cropRect == null
                        ? 'JPG / PNG対応'
                        : '枠内をドラッグで移動・四隅でサイズ変更',
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
