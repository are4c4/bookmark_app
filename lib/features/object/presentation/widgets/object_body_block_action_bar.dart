import 'package:flutter/material.dart';

import '../../../../domain/object_body.dart';
import '../../../../domain/object_body_block_actions.dart';

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
          PopupMenuButton<ObjectBodyInsertKind>(
            key: ValueKey('body-block-insert-after-${block.id}'),
            tooltip: '下にブロックを追加',
            onSelected: onInsertAfter,
            itemBuilder: (context) => [
              for (final kind in ObjectBodyInsertKind.values)
                PopupMenuItem(
                  value: kind,
                  child: Text(_label(kind)),
                ),
            ],
            icon: const Icon(Icons.add),
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

  String _label(ObjectBodyInsertKind kind) => switch (kind) {
        ObjectBodyInsertKind.paragraph => 'テキスト',
        ObjectBodyInsertKind.heading1 => '見出し 1',
        ObjectBodyInsertKind.heading2 => '見出し 2',
        ObjectBodyInsertKind.heading3 => '見出し 3',
        ObjectBodyInsertKind.bulletedListItem => '箇条書き',
        ObjectBodyInsertKind.numberedListItem => '番号付きリスト',
        ObjectBodyInsertKind.checklist => 'チェックリスト',
        ObjectBodyInsertKind.quote => '引用',
        ObjectBodyInsertKind.callout => 'コールアウト',
        ObjectBodyInsertKind.code => 'コード',
        ObjectBodyInsertKind.divider => '区切り線',
      };
}
