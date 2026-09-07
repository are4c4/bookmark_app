import 'package:flutter/material.dart';

import '../data/database_view_property_type_conversion_service.dart';

Future<bool> showPropertyTypeClearMigrationDialog({
  required BuildContext context,
  required PropertyTypeConversionImpact impact,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => PropertyTypeClearMigrationDialog(impact: impact),
    ) ??
    false;

/// Explicit destructive confirmation for a Value Property type change whose
/// current values cannot be migrated safely.
///
/// This widget never mutates data. The caller must route the confirmed action
/// through the transactional clear-values migration service.
class PropertyTypeClearMigrationDialog extends StatefulWidget {
  const PropertyTypeClearMigrationDialog({
    super.key,
    required this.impact,
  });

  final PropertyTypeConversionImpact impact;

  @override
  State<PropertyTypeClearMigrationDialog> createState() =>
      _PropertyTypeClearMigrationDialogState();
}

class _PropertyTypeClearMigrationDialogState
    extends State<PropertyTypeClearMigrationDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final impact = widget.impact;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('既存値をクリアして型を変更'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${impact.property.name} の既存値は安全に変換できません。',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${impact.objectsWithStoredValue}件のObjectからこのPropertyの保存値を削除してから型を変更します。値は元に戻せません。',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              key: const ValueKey('property-type-clear-confirm-checkbox'),
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              title: const Text('既存値が削除されることを理解しました'),
              onChanged: (value) => setState(() => _confirmed = value == true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const ValueKey('property-type-clear-confirm'),
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: const Text('値をクリアして変更'),
        ),
      ],
    );
  }
}
