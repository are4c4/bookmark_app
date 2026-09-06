import 'dart:async';

import 'package:bookmark_app/data/relation_target_quick_create_policy.dart';
import 'package:flutter/material.dart';

typedef RelationTargetQuickCreateCallback = FutureOr<void> Function();

/// Presentation-only affordance for creating a new target from a Relation value
/// picker.
///
/// The actual mutation is always supplied by the host so identity-sensitive
/// built-in primitives continue to use their canonical creation/import paths.
/// `unavailable` intentionally renders nothing rather than falling back to
/// title-only Object creation.
class RelationTargetQuickCreateAction extends StatelessWidget {
  const RelationTargetQuickCreateAction({
    super.key,
    required this.mode,
    required this.onCreate,
  });

  final RelationTargetQuickCreateMode mode;
  final RelationTargetQuickCreateCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    if (mode == RelationTargetQuickCreateMode.unavailable || onCreate == null) {
      return const SizedBox.shrink();
    }

    final presentation = switch (mode) {
      RelationTargetQuickCreateMode.genericObject => const (
          label: '新しいObjectを作成',
          icon: Icons.add_circle_outline,
          tooltip: 'カスタムObjectを作成',
        ),
      RelationTargetQuickCreateMode.tag => const (
          label: '新しいタグを作成',
          icon: Icons.sell_outlined,
          tooltip: 'タグを作成',
        ),
      RelationTargetQuickCreateMode.weblinkUrl => const (
          label: 'URLからWeblinkを追加',
          icon: Icons.link_outlined,
          tooltip: 'URLからWeblinkを作成',
        ),
      RelationTargetQuickCreateMode.managedImage => const (
          label: '画像をインポート',
          icon: Icons.image_outlined,
          tooltip: '画像を管理領域へインポート',
        ),
      RelationTargetQuickCreateMode.managedFile => const (
          label: 'ファイルをインポート',
          icon: Icons.attach_file_outlined,
          tooltip: 'ファイルを管理領域へインポート',
        ),
      RelationTargetQuickCreateMode.unavailable => throw StateError(
          'Unavailable quick-create mode must not render an action.',
        ),
    };

    return Tooltip(
      message: presentation.tooltip,
      child: TextButton.icon(
        key: ValueKey('relation-target-quick-create-${mode.name}'),
        onPressed: () async => onCreate!(),
        icon: Icon(presentation.icon, size: 18),
        label: Text(presentation.label),
      ),
    );
  }
}
