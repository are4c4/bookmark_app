import 'package:flutter/material.dart';

import '../../../../domain/object_body_block_actions.dart';

/// Shared menu for creating generic, non-reference Body blocks.
///
/// It can be used both after an existing block and from an empty Body. Hosts
/// remain responsible for generating the new block id and persisting insertion.
class ObjectBodyInsertMenuButton extends StatelessWidget {
  const ObjectBodyInsertMenuButton({
    super.key,
    required this.onSelected,
    this.tooltip = 'ブロックを追加',
  });

  final ValueChanged<ObjectBodyInsertKind> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ObjectBodyInsertKind>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final kind in ObjectBodyInsertKind.values)
          PopupMenuItem(
            value: kind,
            child: Text(labelFor(kind)),
          ),
      ],
      icon: const Icon(Icons.add),
    );
  }

  static String labelFor(ObjectBodyInsertKind kind) => switch (kind) {
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
