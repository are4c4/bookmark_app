import 'dart:io';

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

  int _quarterTurns = 0;
  bool _flipHorizontal = false;
  double? _cropRatio;
  bool _saving = false;
  bool _hasBackup = false;

  static const _cropOptions = <String, double?>{
    '元の比率': null,
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
  }

  Future<void> _loadBackupState() async {
    final value = await _service.hasBackup(widget.path);
    if (mounted) setState(() => _hasBackup = value);
  }

  Widget _preview() {
    Widget image = Image.file(
      File(widget.path),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
    );

    image = RotatedBox(quarterTurns: _quarterTurns, child: image);
    if (_flipHorizontal) {
      image = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: image,
      );
    }

    final ratio = _cropRatio;
    if (ratio != null) {
      return AspectRatio(
        aspectRatio: ratio,
        child: ClipRect(
          child: SizedBox.expand(
            child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: 900, height: 900, child: image)),
          ),
        ),
      );
    }
    return Center(child: image);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.apply(
        path: widget.path,
        quarterTurns: _quarterTurns,
        flipHorizontal: _flipHorizontal,
        cropAspectRatio: _cropRatio,
      );
      await FileImage(File(widget.path)).evict();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('画像を編集できませんでした: $error')));
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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('元に戻す')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('元画像に戻せませんでした: $error')));
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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                    onPressed: () => setState(() => _quarterTurns = (_quarterTurns + 3) % 4),
                    icon: const Icon(Icons.rotate_left),
                  ),
                  IconButton(
                    tooltip: '右へ90°回転',
                    onPressed: () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
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
                  const Text('トリミング', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<double?>(
                    value: _cropRatio,
                    items: _cropOptions.entries
                        .map((entry) => DropdownMenuItem<double?>(value: entry.value, child: Text(entry.key)))
                        .toList(),
                    onChanged: (value) => setState(() => _cropRatio = value),
                  ),
                  const Spacer(),
                  Text(
                    'JPG / PNG対応',
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
