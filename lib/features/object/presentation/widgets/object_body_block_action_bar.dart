import 'package:flutter/material.dart';

import '../../../../domain/object_body.dart';
import '../../../../domain/object_body_block_actions.dart';
import 'object_body_insert_menu_button.dart';

/// Shared per-block editing chrome for Body hosts.
///
/// The widget is intentionally persistence-agnostic: hosts decide how to
/// create block ids and dispatch the callbacks to ObjectBodyBlockEditService.
class ObjectBodyBlockActionBar extends StatelessWidget {
  const ObjectBodyBlockActionBar({
    super.key,
    required this.block,
    required this.position,
    this.onMoveUp,
    this.onMoveDown,
    this.onDelete,
    this.onInsertAfter,
  });

  final ObjectBodyBlock block;
  final ObjectBodyBlockPosition position;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDelete;
  final ValueChanged<ObjectBodyInsertKind>? onInsertAfter;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('body-block-move-up-${block.id}'),
          tooltip: '上へ移動',
          onPressed: position.canMoveUp ? onMoveUp : null,
          icon: const Icon(Icons.arrow_upward),
        ),
        IconButton(
          key: ValueKey('body-block-move-down-${block.id}'),
          tooltip: '下へ移動',
          onPressed: position.canMoveDown ? onMoveDown : null,
          icon: const Icon(Icons.arrow_downward),
        ),
        if (onInsertAfter != null)
          ObjectBodyInsertMenuButton(
            key: ValueKey('body-block-insert-after-${block.id}'),
            tooltip: '下にブロックを追加',
            onSelected: onInsertAfter!,
          ),
        IconButton(
          key: ValueKey('body-block-delete-${block.id}'),
          tooltip: '削除',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
