import 'package:flutter/material.dart';

import '../../../../domain/object_body_reference_insert.dart';

/// Shared menu that starts explicit target-selection flows for reference-bearing
/// Body blocks. Selecting a kind does not persist anything by itself.
class ObjectBodyReferenceInsertMenuButton extends StatelessWidget {
  const ObjectBodyReferenceInsertMenuButton({
    super.key,
    required this.onSelected,
    this.tooltip = '参照を追加',
    this.kinds = ObjectBodyReferenceInsertKind.values,
  });

  final ValueChanged<ObjectBodyReferenceInsertKind> onSelected;
  final String tooltip;

  /// Reference kinds the current host can complete with an explicit target.
  ///
  /// Defaults to every known kind so existing hosts keep their current
  /// behavior. A partially integrated host can expose only the flows it can
  /// actually complete instead of offering placeholder-producing actions.
  final List<ObjectBodyReferenceInsertKind> kinds;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ObjectBodyReferenceInsertKind>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final kind in kinds)
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
