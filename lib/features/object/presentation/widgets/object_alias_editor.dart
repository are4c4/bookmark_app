import 'package:flutter/material.dart';

/// Shared Object identity metadata surface for alternate names.
///
/// Aliases are presentation/search metadata only. Hosts remain responsible for
/// persisting them against the canonical Object id.
class ObjectAliasEditor extends StatelessWidget {
  const ObjectAliasEditor({
    super.key,
    required this.aliases,
    this.onAdd,
    this.onRemove,
  });

  final List<String> aliases;
  final Future<void> Function(String alias)? onAdd;
  final Future<void> Function(String alias)? onRemove;

  Future<void> _promptAdd(BuildContext context) async {
    var value = '';
    final alias = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('別名を追加'),
        content: TextField(
          key: const ValueKey('object-alias-add-field'),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '別名',
          ),
          onChanged: (text) => value = text,
          onSubmitted: (_) {
            final cleaned = value.trim();
            if (cleaned.isNotEmpty) Navigator.pop(dialogContext, cleaned);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const ValueKey('object-alias-add-save'),
            onPressed: () {
              final cleaned = value.trim();
              if (cleaned.isNotEmpty) Navigator.pop(dialogContext, cleaned);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (alias == null || onAdd == null) return;
    await onAdd!(alias);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('object-alias-editor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '別名',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                key: const ValueKey('object-alias-add-button'),
                onPressed: () => _promptAdd(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('追加'),
              ),
            ],
          ],
        ),
        if (aliases.isEmpty)
          Text(
            '別名はありません',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: aliases
                .map(
                  (alias) => InputChip(
                    key: ValueKey('object-alias-chip:$alias'),
                    label: Text(alias),
                    visualDensity: VisualDensity.compact,
                    onDeleted: onRemove == null
                        ? null
                        : () async {
                            await onRemove!(alias);
                          },
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}
