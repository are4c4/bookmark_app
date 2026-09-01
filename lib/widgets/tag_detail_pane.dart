import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/tag_group_store.dart';
import '../ui/ui_tokens.dart';

class TagDetailPane extends StatelessWidget {
  const TagDetailPane({
    super.key,
    required this.tag,
    required this.usage,
    required this.parent,
    required this.group,
    required this.childCount,
    required this.onRename,
    required this.onMove,
    required this.onMerge,
    required this.onDelete,
    required this.onShowDirect,
    required this.onShowAggregate,
  });

  final Tag? tag;
  final TagUsageStats? usage;
  final Tag? parent;
  final TagGroupInfo? group;
  final int childCount;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onMerge;
  final VoidCallback onDelete;
  final VoidCallback onShowDirect;
  final VoidCallback onShowAggregate;

  @override
  Widget build(BuildContext context) {
    final selected = tag;
    final scheme = Theme.of(context).colorScheme;
    if (selected == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(UiTokens.space24),
            child: Text('タグを選択すると詳細を表示します'),
          ),
        ),
      );
    }
    final counts = usage ??
        const TagUsageStats(directCount: 0, aggregateCount: 0);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(UiTokens.space16),
        children: [
          Row(
            children: [
              const Icon(Icons.sell_outlined, size: UiTokens.iconNormal),
              const SizedBox(width: UiTokens.space8),
              Expanded(
                child: Text(
                  selected.name,
                  style: const TextStyle(
                    fontSize: UiTokens.textLg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: UiTokens.space16),
          _property('親タグ', parent?.name ?? 'なし（最上位）'),
          _property('グループ', group?.name ?? 'その他タグ'),
          _property('子タグ', '$childCount件'),
          const SizedBox(height: UiTokens.space12),
          Row(
            children: [
              Expanded(
                child: _CountCard(
                  label: '直接使用',
                  value: counts.directCount,
                  onTap: onShowDirect,
                ),
              ),
              const SizedBox(width: UiTokens.space8),
              Expanded(
                child: _CountCard(
                  label: '子孫を含む',
                  value: counts.aggregateCount,
                  onTap: onShowAggregate,
                ),
              ),
            ],
          ),
          const SizedBox(height: UiTokens.space16),
          const Divider(),
          const SizedBox(height: UiTokens.space8),
          ListTile(
            dense: true,
            leading: const Icon(Icons.edit_outlined, size: 18),
            title: const Text('名前を変更'),
            onTap: onRename,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.drive_file_move_outline, size: 18),
            title: const Text('親・グループを変更'),
            onTap: onMove,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.merge_outlined, size: 18),
            title: const Text('別のタグへ統合'),
            onTap: onMerge,
          ),
          ListTile(
            dense: true,
            textColor: scheme.error,
            iconColor: scheme.error,
            leading: const Icon(Icons.delete_outline, size: 18),
            title: const Text('削除'),
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _property(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: UiTokens.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              child: Text(
                label,
                style: const TextStyle(fontSize: UiTokens.textSm),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: UiTokens.textMd),
              ),
            ),
          ],
        ),
      );
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(UiTokens.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(UiTokens.space12),
            child: Column(
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: UiTokens.space2),
                Text(
                  label,
                  style: const TextStyle(fontSize: UiTokens.textSm),
                ),
              ],
            ),
          ),
        ),
      );
}
