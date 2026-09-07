import 'package:flutter/material.dart';

import '../data/database_view_property_schema_service.dart';

typedef ObjectPropertyViewReferenceDetach =
    Future<ObjectPropertyDeleteImpact> Function();

/// Presents the read-only impact of deleting a user-defined Property.
///
/// Deletion is enabled only when no Object value, persisted View setting, or
/// managed bidirectional Relation pair would be affected. Callers may provide
/// [onDetachViewReferences] to let the user explicitly remove only Database/View
/// references and return a freshly inspected impact. Stored Object values and
/// Relation schema remain separate blockers and are never cleared by this UX.
Future<bool?> showObjectPropertyDeleteImpactDialog(
  BuildContext context, {
  required ObjectPropertyDeleteImpact impact,
  ObjectPropertyViewReferenceDetach? onDetachViewReferences,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => ObjectPropertyDeleteImpactDialog(
      impact: impact,
      onDetachViewReferences: onDetachViewReferences,
    ),
  );
}

class ObjectPropertyDeleteImpactDialog extends StatefulWidget {
  const ObjectPropertyDeleteImpactDialog({
    super.key,
    required this.impact,
    this.onDetachViewReferences,
  });

  final ObjectPropertyDeleteImpact impact;
  final ObjectPropertyViewReferenceDetach? onDetachViewReferences;

  @override
  State<ObjectPropertyDeleteImpactDialog> createState() =>
      _ObjectPropertyDeleteImpactDialogState();
}

class _ObjectPropertyDeleteImpactDialogState
    extends State<ObjectPropertyDeleteImpactDialog> {
  late ObjectPropertyDeleteImpact _impact;
  bool _detachingViewReferences = false;
  bool _detachFailed = false;

  bool get _canDelete =>
      !_impact.hasStoredValues &&
      !_impact.isReferencedByViews &&
      !_impact.hasPairedRelationImpact;

  @override
  void initState() {
    super.initState();
    _impact = widget.impact;
  }

  @override
  void didUpdateWidget(covariant ObjectPropertyDeleteImpactDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.impact != widget.impact) {
      _impact = widget.impact;
      _detachFailed = false;
    }
  }

  Future<void> _detachViewReferences() async {
    final detach = widget.onDetachViewReferences;
    if (detach == null ||
        !_impact.isReferencedByViews ||
        _detachingViewReferences) {
      return;
    }

    setState(() {
      _detachingViewReferences = true;
      _detachFailed = false;
    });
    try {
      final refreshed = await detach();
      if (refreshed.property.id != _impact.property.id ||
          refreshed.property.objectTypeId != _impact.property.objectTypeId) {
        throw StateError('Property impact identity changed during View detach.');
      }
      if (!mounted) return;
      setState(() {
        _impact = refreshed;
        _detachingViewReferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detachingViewReferences = false;
        _detachFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('「${_impact.property.name}」を削除'),
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
                value: '${_impact.objectsWithStoredValue}件',
                warning: _impact.hasStoredValues,
              ),
              _ImpactRow(
                label: '参照しているView',
                value: '${_impact.viewReferences.length}件',
                warning: _impact.isReferencedByViews,
              ),
              if (_impact.pairedRelationProperty case final paired?)
                _ImpactRow(
                  label: '双方向Relationの相手Property',
                  value: paired.name,
                  warning: true,
                ),
              if (_impact.viewReferences.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'View参照',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                ..._impact.viewReferences.map(
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
                if (widget.onDetachViewReferences != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      key: const ValueKey('property-delete-detach-views'),
                      onPressed: _detachingViewReferences
                          ? null
                          : _detachViewReferences,
                      icon: _detachingViewReferences
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link_off_outlined),
                      label: Text(
                        _detachingViewReferences
                            ? 'View参照を解除中…'
                            : 'View参照を外す',
                      ),
                    ),
                  ),
                ],
              ],
              if (_detachFailed) ...[
                const SizedBox(height: 10),
                Text(
                  'View参照を外せませんでした。設定を確認して再試行してください。',
                  key: const ValueKey('property-delete-detach-error'),
                  style: TextStyle(color: scheme.error),
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
