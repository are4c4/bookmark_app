import 'package:flutter/material.dart';

import '../data/database_view_property_schema_service.dart';

/// Presents the read-only impact of deleting a user-defined Property.
///
/// Deletion is enabled only when no Object value, persisted View setting, or
/// managed bidirectional Relation pair would be affected. This keeps the first
/// destructive UX fail-closed: callers must migrate/clear data, detach View
/// configuration, and choose an explicit paired-Relation lifecycle before
/// invoking their canonical deletion path.
Future<bool?> showObjectPropertyDeleteImpactDialog(
  BuildContext context, {
  required ObjectPropertyDeleteImpact impact,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => ObjectPropertyDeleteImpactDialog(
      impact: impact,
    ),
  );
}

class ObjectPropertyDeleteImpactDialog extends StatelessWidget {
  const ObjectPropertyDeleteImpactDialog({
    super.key,
    required this.impact,
  });

  final ObjectPropertyDeleteImpact impact;

  bool get _canDelete =>
      !impact.hasStoredValues &&
      !impact.isReferencedByViews &&
      !impact.hasPairedRelationImpact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('「${impact.property.name}」を削除'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_canDelete)
                const Text(
                  '保存値やView参照はありません。このPropertyを削除できます。',
                )
              else ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'データ・View設定・関連するRelation schemaを失わないため、'
                      'この状態では削除できません。影響を解消してから再度実行してください。',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _ImpactRow(
                label: '値を保存しているObject',
                value: '${impact.objectsWithStoredValue}件',
                warning: impact.hasStoredValues,
              ),
              _ImpactRow(
                label: '参照しているView',
                value: '${impact.viewReferences.length}件',
                warning: impact.isReferencedByViews,
              ),
              if (impact.pairedRelationProperty case final paired?)
                _ImpactRow(
                  label: '双方向Relationの相手Property',
                  value: paired.name,
                  warning: true,
                ),
              if (impact.viewReferences.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'View参照',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                ...impact.viewReferences.map(
                  (reference) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reference.viewName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              reference.kinds.map(_kindLabel).join(' / '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(_canDelete ? 'キャンセル' : '閉じる'),
        ),
        FilledButton(
          key: const ValueKey('property-delete-confirm'),
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          child: const Text('削除する'),
        ),
      ],
    );
  }

  static String _kindLabel(DatabaseViewPropertyReferenceKind kind) =>
      switch (kind) {
        DatabaseViewPropertyReferenceKind.visible => '表示',
        DatabaseViewPropertyReferenceKind.order => 'プロパティ順',
        DatabaseViewPropertyReferenceKind.filter => 'フィルター',
        DatabaseViewPropertyReferenceKind.sort => '並び替え',
        DatabaseViewPropertyReferenceKind.group => 'グループ',
        DatabaseViewPropertyReferenceKind.galleryCover => 'ギャラリーカバー',
      };
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.label,
    required this.value,
    required this.warning,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: warning ? scheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
