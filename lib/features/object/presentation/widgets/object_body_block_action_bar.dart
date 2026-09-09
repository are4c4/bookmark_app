import 'package:flutter/material.dart';

import '../../../../domain/object_body.dart';
import '../../../../domain/object_body_block_actions.dart';
import '../../../../domain/object_body_reference_insert.dart';
import 'object_body_insert_menu_button.dart';
import 'object_body_reference_insert_menu_button.dart';

/// Shared per-block editing chrome for Body hosts.
///
/// Frequent insertion remains one click away while lower-frequency movement,
/// duplication and deletion live behind one compact overflow menu. This keeps
/// an idle Body visually document-like instead of rendering a full toolbar
/// after every block.
class ObjectBodyBlockActionBar extends StatelessWidget {
  const ObjectBodyBlockActionBar({
    super.key,
    required this.block,
    required this.position,
    this.onMoveUp,
    this.onMoveDown,
    this.onDuplicate,
    this.onDelete,
    this.onInsertAfter,
    this.onInsertReferenceAfter,
    this.referenceInsertKinds = ObjectBodyReferenceInsertKind.values,
  });

  final ObjectBodyBlock block;
  final ObjectBodyBlockPosition position;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final ValueChanged<ObjectBodyInsertKind>? onInsertAfter;
  final ValueChanged<ObjectBodyReferenceInsertKind>? onInsertReferenceAfter;
  final List<ObjectBodyReferenceInsertKind> referenceInsertKinds;

  bool get _hasOverflowActions =>
      onMoveUp != null ||
      onMoveDown != null ||
      onDuplicate != null ||
      onDelete != null;

  @override
  Widget build(BuildContext context) {
    return IconTheme.merge(
      data: const IconThemeData(size: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onInsertAfter != null)
            ObjectBodyInsertMenuButton(
              key: ValueKey('body-block-insert-after-${block.id}'),
              tooltip: '下にブロックを追加',
              onSelected: onInsertAfter!,
            ),
          if (onInsertReferenceAfter != null)
            ObjectBodyReferenceInsertMenuButton(
              key: ValueKey('body-block-insert-reference-after-${block.id}'),
              tooltip: '下に参照を追加',
              allowedKinds: referenceInsertKinds,
              onSelected: onInsertReferenceAfter!,
            ),
          if (_hasOverflowActions)
            PopupMenuButton<_ObjectBodyBlockMenuAction>(
              key: ValueKey('body-block-more-${block.id}'),
              tooltip: 'ブロック操作',
              icon: const Icon(Icons.more_horiz),
              onSelected: _dispatchOverflowAction,
              itemBuilder: (context) => [
                if (onMoveUp != null)
                  PopupMenuItem(
                    key: ValueKey('body-block-move-up-${block.id}'),
                    value: _ObjectBodyBlockMenuAction.moveUp,
                    enabled: position.canMoveUp,
                    child: const _BodyBlockMenuLabel(
                      icon: Icons.arrow_upward,
                      label: '上へ移動',
                    ),
                  ),
                if (onMoveDown != null)
                  PopupMenuItem(
                    key: ValueKey('body-block-move-down-${block.id}'),
                    value: _ObjectBodyBlockMenuAction.moveDown,
                    enabled: position.canMoveDown,
                    child: const _BodyBlockMenuLabel(
                      icon: Icons.arrow_downward,
                      label: '下へ移動',
                    ),
                  ),
                if (onDuplicate != null)
                  PopupMenuItem(
                    key: ValueKey('body-block-duplicate-${block.id}'),
                    value: _ObjectBodyBlockMenuAction.duplicate,
                    child: const _BodyBlockMenuLabel(
                      icon: Icons.copy_outlined,
                      label: '複製',
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    key: ValueKey('body-block-delete-${block.id}'),
                    value: _ObjectBodyBlockMenuAction.delete,
                    child: const _BodyBlockMenuLabel(
                      icon: Icons.delete_outline,
                      label: '削除',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _dispatchOverflowAction(_ObjectBodyBlockMenuAction action) {
    switch (action) {
      case _ObjectBodyBlockMenuAction.moveUp:
        onMoveUp?.call();
      case _ObjectBodyBlockMenuAction.moveDown:
        onMoveDown?.call();
      case _ObjectBodyBlockMenuAction.duplicate:
        onDuplicate?.call();
      case _ObjectBodyBlockMenuAction.delete:
        onDelete?.call();
    }
  }
}

enum _ObjectBodyBlockMenuAction { moveUp, moveDown, duplicate, delete }

class _BodyBlockMenuLabel extends StatelessWidget {
  const _BodyBlockMenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)],
    );
  }
}
