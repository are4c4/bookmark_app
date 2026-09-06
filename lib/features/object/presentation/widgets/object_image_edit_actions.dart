import 'package:flutter/material.dart';

import '../../../../services/canonical_image_edit_service.dart';

typedef ObjectImageFreeCropRectSelector = Future<Rect?> Function(
  BuildContext context,
);

/// Small presentation seam for safe canonical Image edits.
///
/// The widget never resolves file paths itself and never calls [ImageEditService]
/// directly. Availability and mutations stay behind [CanonicalImageEditService]
/// so shared/ambiguous managed files continue to fail closed.
class ObjectImageEditActions extends StatefulWidget {
  const ObjectImageEditActions({
    super.key,
    required this.editService,
    required this.workspaceId,
    required this.objectId,
    this.freeCropSelector,
    this.onChanged,
    this.onError,
  });

  final CanonicalImageEditService editService;
  final int workspaceId;
  final int objectId;

  /// Optional UI-only selector for a normalized free-crop rectangle.
  ///
  /// The selector must not mutate image bytes. Its result is routed back through
  /// [CanonicalImageEditService.edit], which repeats ownership/format checks.
  final ObjectImageFreeCropRectSelector? freeCropSelector;
  final VoidCallback? onChanged;
  final void Function(Object error)? onError;

  @override
  State<ObjectImageEditActions> createState() => _ObjectImageEditActionsState();
}

class _ObjectImageEditActionsState extends State<ObjectImageEditActions> {
  late Future<_ImageEditAvailability> _availability;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _availability = _loadAvailability();
  }

  @override
  void didUpdateWidget(covariant ObjectImageEditActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editService != widget.editService ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.objectId != widget.objectId) {
      _availability = _loadAvailability();
    }
  }

  Future<_ImageEditAvailability> _loadAvailability() async {
    final values = await Future.wait<bool>([
      widget.editService.canEdit(
        workspaceId: widget.workspaceId,
        objectId: widget.objectId,
      ),
      widget.editService.canRestoreOriginal(
        workspaceId: widget.workspaceId,
        objectId: widget.objectId,
      ),
    ]);
    return _ImageEditAvailability(
      canEdit: values[0],
      canRestore: values[1],
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      widget.onChanged?.call();
      setState(() => _availability = _loadAvailability());
    } catch (error) {
      widget.onError?.call(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rotate(int quarterTurns) => _run(() async {
        await widget.editService.edit(
          workspaceId: widget.workspaceId,
          objectId: widget.objectId,
          quarterTurns: quarterTurns,
        );
      });

  Future<void> _flipHorizontal() => _run(() async {
        await widget.editService.edit(
          workspaceId: widget.workspaceId,
          objectId: widget.objectId,
          flipHorizontal: true,
        );
      });

  Future<void> _flipVertical() => _run(() async {
        // A vertical reflection is equivalent to a 180° rotation followed by
        // the existing horizontal reflection. Keeping the composition here
        // avoids widening the canonical byte-mutation API solely for UI parity.
        await widget.editService.edit(
          workspaceId: widget.workspaceId,
          objectId: widget.objectId,
          quarterTurns: 2,
          flipHorizontal: true,
        );
      });

  Future<void> _cropAspectRatio(double ratio) => _run(() async {
        await widget.editService.edit(
          workspaceId: widget.workspaceId,
          objectId: widget.objectId,
          cropAspectRatio: ratio,
        );
      });

  Future<void> _freeCrop() async {
    final selector = widget.freeCropSelector;
    if (selector == null || _busy) return;
    try {
      final rect = await selector(context);
      if (!mounted || rect == null) return;
      await _run(() async {
        await widget.editService.edit(
          workspaceId: widget.workspaceId,
          objectId: widget.objectId,
          normalizedCropRect: rect,
        );
      });
    } catch (error) {
      widget.onError?.call(error);
    }
  }

  Future<void> _restore() => _run(() async {
        await widget.editService.restoreOriginal(
          workspaceId: widget.workspaceId,
          objectId: widget.objectId,
        );
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ImageEditAvailability>(
      future: _availability,
      builder: (context, snapshot) {
        final availability = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;
        final canEdit = !_busy && !loading && availability?.canEdit == true;
        final canRestore =
            !_busy && !loading && availability?.canRestore == true;

        return Wrap(
          key: ValueKey('object-image-edit-actions-${widget.objectId}'),
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_busy || loading)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            IconButton.outlined(
              key: const ValueKey('object-image-rotate-left'),
              tooltip: '左に90°回転',
              onPressed: canEdit ? () => _rotate(3) : null,
              icon: const Icon(Icons.rotate_left),
            ),
            IconButton.outlined(
              key: const ValueKey('object-image-rotate-right'),
              tooltip: '右に90°回転',
              onPressed: canEdit ? () => _rotate(1) : null,
              icon: const Icon(Icons.rotate_right),
            ),
            IconButton.outlined(
              key: const ValueKey('object-image-flip-horizontal'),
              tooltip: '左右反転',
              onPressed: canEdit ? _flipHorizontal : null,
              icon: const Icon(Icons.flip),
            ),
            IconButton.outlined(
              key: const ValueKey('object-image-flip-vertical'),
              tooltip: '上下反転',
              onPressed: canEdit ? _flipVertical : null,
              icon: const RotatedBox(
                quarterTurns: 1,
                child: Icon(Icons.flip),
              ),
            ),
            PopupMenuButton<double>(
              key: const ValueKey('object-image-crop-aspect-ratio'),
              tooltip: '中央トリミング',
              enabled: canEdit,
              onSelected: _cropAspectRatio,
              icon: const Icon(Icons.crop),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 1.0,
                  child: Text('正方形 1:1'),
                ),
                PopupMenuItem(
                  value: 4 / 3,
                  child: Text('横 4:3'),
                ),
                PopupMenuItem(
                  value: 3 / 4,
                  child: Text('縦 3:4'),
                ),
                PopupMenuItem(
                  value: 16 / 9,
                  child: Text('ワイド 16:9'),
                ),
                PopupMenuItem(
                  value: 9 / 16,
                  child: Text('縦長 9:16'),
                ),
              ],
            ),
            if (widget.freeCropSelector != null)
              OutlinedButton.icon(
                key: const ValueKey('object-image-free-crop'),
                onPressed: canEdit ? _freeCrop : null,
                icon: const Icon(Icons.crop_free),
                label: const Text('自由'),
              ),
            OutlinedButton.icon(
              key: const ValueKey('object-image-restore-original'),
              onPressed: canRestore ? _restore : null,
              icon: const Icon(Icons.restore),
              label: const Text('元画像に戻す'),
            ),
          ],
        );
      },
    );
  }
}

class _ImageEditAvailability {
  const _ImageEditAvailability({
    required this.canEdit,
    required this.canRestore,
  });

  final bool canEdit;
  final bool canRestore;
}
