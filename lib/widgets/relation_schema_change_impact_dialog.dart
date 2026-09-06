import 'package:flutter/material.dart';

import '../data/relation_schema_evolution_service.dart';

class RelationSchemaChangeConfirmation {
  const RelationSchemaChangeConfirmation({
    this.multiToSingleSelections = const <int, int>{},
  });

  final Map<int, int> multiToSingleSelections;
}

Future<RelationSchemaChangeConfirmation?> showRelationSchemaChangeImpactDialog({
  required BuildContext context,
  required RelationSchemaChangeImpact impact,
  required String currentTargetLabel,
  required String nextTargetLabel,
  Map<int, String> sourceObjectLabels = const <int, String>{},
  Map<int, String> targetObjectLabels = const <int, String>{},
}) {
  return showDialog<RelationSchemaChangeConfirmation>(
    context: context,
    builder: (_) => RelationSchemaChangeImpactDialog(
      impact: impact,
      currentTargetLabel: currentTargetLabel,
      nextTargetLabel: nextTargetLabel,
      sourceObjectLabels: sourceObjectLabels,
      targetObjectLabels: targetObjectLabels,
    ),
  );
}

/// UI-only confirmation layer for the canonical Relation schema evolution
/// preflight contract.
///
/// This dialog never mutates Relation state. Callers must first obtain [impact]
/// from `RelationSchemaEvolutionService.inspectChange(...)`, then pass the
/// returned explicit selections back to `updateRelationSchema(...)`. Apply
/// re-validates transactionally, so this preview is informative rather than an
/// alternate integrity path.
class RelationSchemaChangeImpactDialog extends StatefulWidget {
  const RelationSchemaChangeImpactDialog({
    super.key,
    required this.impact,
    required this.currentTargetLabel,
    required this.nextTargetLabel,
    this.sourceObjectLabels = const <int, String>{},
    this.targetObjectLabels = const <int, String>{},
  });

  final RelationSchemaChangeImpact impact;
  final String currentTargetLabel;
  final String nextTargetLabel;
  final Map<int, String> sourceObjectLabels;
  final Map<int, String> targetObjectLabels;

  @override
  State<RelationSchemaChangeImpactDialog> createState() =>
      _RelationSchemaChangeImpactDialogState();
}

class _RelationSchemaChangeImpactDialogState
    extends State<RelationSchemaChangeImpactDialog> {
  final Map<int, int> _selections = <int, int>{};

  bool get _canConfirm => widget.impact.multiToSingleConflicts.keys
      .every(_selections.containsKey);

  @override
  Widget build(BuildContext context) {
    final impact = widget.impact;
    return AlertDialog(
      title: const Text('Relation Propertyを変更'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                impact.property.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (impact.changesTargetObjectType)
                _ImpactRow(
                  key: const ValueKey('relation-schema-target-change'),
                  label: '関連先',
                  before: widget.currentTargetLabel,
                  after: widget.nextTargetLabel,
                ),
              if (impact.changesCardinality)
                _ImpactRow(
                  key: const ValueKey('relation-schema-cardinality-change'),
                  label: '関連できる数',
                  before: impact.currentMultiple ? 'multi' : 'single',
                  after: impact.nextMultiple ? 'multi' : 'single',
                ),
              const SizedBox(height: 10),
              Text(
                '値が入っているObject: ${impact.affectedSourceObjectCount}件',
                key: const ValueKey('relation-schema-affected-count'),
              ),
              if (impact.requiresMultiToSingleChoice) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'multi から single に変更するには、複数の関連先を持つ各Objectで残す1件を選んでください。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...impact.multiToSingleConflicts.entries.map(
                  (entry) => _buildConflictChoice(entry.key, entry.value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const ValueKey('relation-schema-confirm'),
          onPressed: _canConfirm
              ? () => Navigator.pop(
                    context,
                    RelationSchemaChangeConfirmation(
                      multiToSingleSelections:
                          Map<int, int>.unmodifiable(_selections),
                    ),
                  )
              : null,
          child: const Text('変更を続ける'),
        ),
      ],
    );
  }

  Widget _buildConflictChoice(int sourceObjectId, List<int> targetObjectIds) {
    final sourceLabel =
        widget.sourceObjectLabels[sourceObjectId] ?? 'Object #$sourceObjectId';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        key: ValueKey('relation-schema-choice-$sourceObjectId'),
        initialValue: _selections[sourceObjectId],
        decoration: InputDecoration(
          isDense: true,
          labelText: sourceLabel,
          helperText: '残す関連先を1件選択',
        ),
        items: targetObjectIds
            .map(
              (targetId) => DropdownMenuItem<int>(
                value: targetId,
                child: Text(
                  widget.targetObjectLabels[targetId] ?? 'Object #$targetId',
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (targetId) {
          if (targetId == null) return;
          setState(() => _selections[sourceObjectId] = targetId);
        },
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    super.key,
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Text('$before  →  $after'),
          ),
        ],
      ),
    );
  }
}
