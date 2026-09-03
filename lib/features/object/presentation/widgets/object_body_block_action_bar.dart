import 'package:flutter/material.dart';

import '../../../../domain/object_body.dart';
import '../../../../domain/object_body_block_actions.dart';
import '../../../../domain/object_body_reference_insert.dart';
import 'object_body_insert_menu_button.dart';
import 'object_body_reference_insert_menu_button.dart';

/// Shared per-block editing chrome for Body hosts.
///
/// The widget is intentionally persistence-agnostic: hosts decide how to
/// dispatch the callbacks to the Object-owned Body services.
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
        if (onDuplicate != null)
          IconButton(
            key: ValueKey('body-block-duplicate-${block.id}'),
            tooltip: '複製',
            onPressed: onDuplicate,
            icon: const Icon(Icons.copy_outlined),
          ),
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
