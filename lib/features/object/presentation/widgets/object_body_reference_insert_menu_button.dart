import 'package:flutter/material.dart';

import '../../../../domain/object_body_reference_insert.dart';

/// Shared menu that starts explicit target-selection flows for reference-bearing
/// Body blocks. Selecting a kind does not persist anything by itself.
class ObjectBodyReferenceInsertMenuButton extends StatelessWidget {
  const ObjectBodyReferenceInsertMenuButton({
    super.key,
    required this.onSelected,
    this.tooltip = '参照を追加',
  });

  final ValueChanged<ObjectBodyReferenceInsertKind> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ObjectBodyReferenceInsertKind>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final kind in ObjectBodyReferenceInsertKind.values)
          PopupMenuItem(
            value: kind,
            child: Text(labelFor(kind)),
          ),
      ],
      icon: const Icon(Icons.add_link),
    );
  }

  static String labelFor(ObjectBodyReferenceInsertKind kind) => switch (kind) {
        ObjectBodyReferenceInsertKind.object => 'Object を参照',
        ObjectBodyReferenceInsertKind.databaseView => 'Database / View を埋め込む',
        ObjectBodyReferenceInsertKind.image => '画像を埋め込む',
        ObjectBodyReferenceInsertKind.file => 'ファイルを埋め込む',
      };
}
