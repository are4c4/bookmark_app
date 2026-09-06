import 'package:flutter/material.dart';

import '../data/database_view_property_type_conversion_service.dart';
import '../data/database_view_property_type_migration_service.dart';
import '../data/object_store.dart';
import '../domain/object_model.dart';
import 'property_type_conversion_impact_dialog.dart';

class ValuePropertySchemaDraft {
  const ValuePropertySchemaDraft({required this.type});

  final ObjectPropertyType type;
}

/// Runs the complete safe type-edit flow for one user-owned Value Property.
///
/// The first dialog only collects the requested destination type. The merged
/// read-only preflight then classifies current data, the impact dialog gathers
/// any explicit narrowing choices, and the transactional migration service
/// re-runs preflight while applying. Presentation never writes Property schema
/// or Object values directly.
Future<ObjectPropertyDefinition?> showValuePropertySchemaEditor({
  required BuildContext context,
  required ObjectPropertyDefinition property,
  required ObjectStore objectStore,
  required DatabaseViewPropertyTypeConversionService conversion,
  required DatabaseViewPropertyTypeMigrationService migration,
}) async {
  if (!property.isValue || !_isEditableValueType(property.type)) {
    throw ArgumentError.value(
      property.id,
      'property',
      'Property must be a user-editable Value Property.',
    );
  }
  final sourceType = await objectStore.getObjectType(property.objectTypeId);
  if (sourceType == null) {
    throw StateError('Property source ObjectType no longer exists.');
  }
  if (sourceType.kind == ObjectTypeKind.system) {
    throw StateError('System ObjectType Properties cannot be retyped by users.');
  }
  ObjectPropertyDefinition? canonical;
  for (final candidate in sourceType.properties) {
    if (candidate.id == property.id) {
      canonical = candidate;
      break;
    }
  }
  if (canonical == null || canonical.type != property.type) {
    throw StateError('Property schema changed before editing started.');
  }

  final draft = await showDialog<ValuePropertySchemaDraft>(
    context: context,
    builder: (_) => ValuePropertySchemaEditorDialog(property: canonical!),
  );
  if (draft == null) return null;

  final impact = await conversion.inspectChange(
    objectTypeId: sourceType.id,
    propertyId: canonical.id,
    nextType: draft.type,
  );
  final objectLabels = <int, String>{
    for (final object in await objectStore.listObjects(sourceType.id))
      object.id: object.title,
  };
  if (!context.mounted) return null;
  final confirmation = await showPropertyTypeConversionImpactDialog(
    context: context,
    impact: impact,
    objectLabels: objectLabels,
  );
  if (confirmation == null) return null;

  final result = await migration.applyChange(
    objectTypeId: sourceType.id,
    propertyId: canonical.id,
    nextType: draft.type,
    multiSelectToSelectChoices: confirmation.explicitChoices,
  );
  return result.property;
}

bool _isEditableValueType(ObjectPropertyType type) => switch (type) {
      ObjectPropertyType.text ||
      ObjectPropertyType.number ||
      ObjectPropertyType.checkbox ||
      ObjectPropertyType.date ||
      ObjectPropertyType.url ||
      ObjectPropertyType.select ||
      ObjectPropertyType.multiSelect ||
      ObjectPropertyType.rating => true,
      _ => false,
    };

class ValuePropertySchemaEditorDialog extends StatefulWidget {
  const ValuePropertySchemaEditorDialog({
    super.key,
    required this.property,
  });

  final ObjectPropertyDefinition property;

  @override
  State<ValuePropertySchemaEditorDialog> createState() =>
      _ValuePropertySchemaEditorDialogState();
}

class _ValuePropertySchemaEditorDialogState
    extends State<ValuePropertySchemaEditorDialog> {
  late ObjectPropertyType _type;

  static const _types = <ObjectPropertyType>[
    ObjectPropertyType.text,
    ObjectPropertyType.number,
    ObjectPropertyType.checkbox,
    ObjectPropertyType.date,
    ObjectPropertyType.url,
    ObjectPropertyType.select,
    ObjectPropertyType.multiSelect,
    ObjectPropertyType.rating,
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.property.type;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Value Propertyを編集'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.property.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<ObjectPropertyType>(
              key: const ValueKey('value-property-schema-type'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Property型'),
              items: _types
                  .map(
                    (type) => DropdownMenuItem<ObjectPropertyType>(
                      value: type,
                      child: Text(_label(type)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
            ),
            const SizedBox(height: 10),
            Text(
              '既存値は次の確認画面で検査されます。変換できない値がある場合は変更できません。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const ValueKey('value-property-schema-preview'),
          onPressed: () => Navigator.pop(
            context,
            ValuePropertySchemaDraft(type: _type),
          ),
          child: const Text('変更内容を確認'),
        ),
      ],
    );
  }

  static String _label(ObjectPropertyType type) => switch (type) {
        ObjectPropertyType.text => 'Text',
        ObjectPropertyType.number => 'Number',
        ObjectPropertyType.checkbox => 'Checkbox',
        ObjectPropertyType.date => 'Date',
        ObjectPropertyType.url => 'URL',
        ObjectPropertyType.select => 'Select',
        ObjectPropertyType.multiSelect => 'Multi-select',
        ObjectPropertyType.rating => 'Rating',
        _ => type.name,
      };
}
