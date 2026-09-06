import 'package:flutter/material.dart';

import '../data/database_view_property_type_conversion_service.dart';
import '../domain/object_model.dart';

class PropertyTypeConversionConfirmation {
  const PropertyTypeConversionConfirmation({
    this.explicitChoices = const <int, String>{},
  });

  final Map<int, String> explicitChoices;
}

Future<PropertyTypeConversionConfirmation?> showPropertyTypeConversionImpactDialog({
  required BuildContext context,
  required PropertyTypeConversionImpact impact,
  Map<int, String> objectLabels = const <int, String>{},
}) =>
    showDialog<PropertyTypeConversionConfirmation>(
      context: context,
      builder: (_) => PropertyTypeConversionImpactDialog(
        impact: impact,
        objectLabels: objectLabels,
      ),
    );

/// Confirmation-only UX for a preflighted Value Property type change.
///
/// This dialog performs no schema/value mutation. Callers must re-run preflight
/// at apply time and use a canonical transactional migration path. Destructive or
/// unsupported changes remain disabled rather than offering an implicit clear or
/// coercion action.
class PropertyTypeConversionImpactDialog extends StatefulWidget {
  const PropertyTypeConversionImpactDialog({
    super.key,
    required this.impact,
    this.objectLabels = const <int, String>{},
  });

  final PropertyTypeConversionImpact impact;
  final Map<int, String> objectLabels;

  @override
  State<PropertyTypeConversionImpactDialog> createState() =>
      _PropertyTypeConversionImpactDialogState();
}

class _PropertyTypeConversionImpactDialogState
    extends State<PropertyTypeConversionImpactDialog> {
  final Map<int, String> _choices = <int, String>{};

  bool get _canConfirm => switch (widget.impact.mode) {
        PropertyTypeConversionMode.noChange ||
        PropertyTypeConversionMode.preserveStoredValues ||
        PropertyTypeConversionMode.transformStoredValues => true,
        PropertyTypeConversionMode.requiresExplicitChoice => widget
            .impact.explicitChoiceOptions.keys
            .every(_choices.containsKey),
        PropertyTypeConversionMode.requiresMigration ||
        PropertyTypeConversionMode.incompatible => false,
      };

  String _objectLabel(int objectId) =>
      widget.objectLabels[objectId] ?? 'Object #$objectId';

  @override
  Widget build(BuildContext context) {
    final impact = widget.impact;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Propertyの型を変更'),
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
              _SummaryRow(
                label: '型',
                value:
                    '${_typeLabel(impact.property.type)}  →  ${_typeLabel(impact.nextType)}',
              ),
              _SummaryRow(
                label: '保存値',
                value: '${impact.objectsWithStoredValue}件のObject',
              ),
              const SizedBox(height: 12),
              _modeMessage(context, impact),
              if (impact.mode ==
                  PropertyTypeConversionMode.requiresExplicitChoice) ...[
                const SizedBox(height: 14),
                ...impact.explicitChoiceOptions.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('property-type-choice-${entry.key}'),
                      initialValue: _choices[entry.key],
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _objectLabel(entry.key),
                        helperText: 'Selectとして残す値を1つ選択',
                      ),
                      items: entry.value
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _choices[entry.key] = value);
                      },
                    ),
                  ),
                ),
              ],
              if (impact.objectsRequiringMigration.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '明示的な移行が必要なObject',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.error,
                      ),
                ),
                const SizedBox(height: 6),
                ...impact.objectsRequiringMigration.map(
                  (objectId) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${_objectLabel(objectId)}'),
                  ),
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
          key: const ValueKey('property-type-conversion-confirm'),
          onPressed: _canConfirm
              ? () => Navigator.pop(
                    context,
                    PropertyTypeConversionConfirmation(
                      explicitChoices:
                          Map<int, String>.unmodifiable(_choices),
                    ),
                  )
              : null,
          child: Text(
            impact.mode == PropertyTypeConversionMode.noChange
                ? '閉じる'
                : '変更を続ける',
          ),
        ),
      ],
    );
  }

  Widget _modeMessage(
    BuildContext context,
    PropertyTypeConversionImpact impact,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final (text, blocking) = switch (impact.mode) {
      PropertyTypeConversionMode.noChange =>
        ('現在と同じ型です。保存値は変更されません。', false),
      PropertyTypeConversionMode.preserveStoredValues =>
        ('既存の保存値はそのまま保持できます。Property IDも変わりません。', false),
      PropertyTypeConversionMode.transformStoredValues =>
        ('既存値を決定的に変換できます。適用時に再検証してから更新します。', false),
      PropertyTypeConversionMode.requiresExplicitChoice =>
        ('複数候補を持つObjectごとに、残す値を明示的に選んでください。', false),
      PropertyTypeConversionMode.requiresMigration =>
        ('この変更には値の移行方針が必要です。暗黙の変換や値の破棄は行いません。', true),
      PropertyTypeConversionMode.incompatible =>
        ('この型変更はValue Propertyの変換経路では扱えません。専用の移行手順が必要です。', true),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: blocking
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          key: const ValueKey('property-type-conversion-message'),
          style: TextStyle(
            color: blocking
                ? scheme.onErrorContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _typeLabel(ObjectPropertyType type) => switch (type) {
        ObjectPropertyType.text => 'Text',
        ObjectPropertyType.number => 'Number',
        ObjectPropertyType.checkbox => 'Checkbox',
        ObjectPropertyType.date => 'Date',
        ObjectPropertyType.url => 'URL',
        ObjectPropertyType.select => 'Select',
        ObjectPropertyType.multiSelect => 'Multi-select',
        ObjectPropertyType.rating => 'Rating',
        ObjectPropertyType.objectRelation => 'Relation',
        ObjectPropertyType.title => 'Title',
        ObjectPropertyType.image => 'Image',
        ObjectPropertyType.file => 'File',
        ObjectPropertyType.createdTime => 'Created time',
        ObjectPropertyType.updatedTime => 'Updated time',
        ObjectPropertyType.formula => 'Formula',
        ObjectPropertyType.rollup => 'Rollup',
      };
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
