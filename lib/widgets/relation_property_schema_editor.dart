import 'package:flutter/material.dart';

import '../data/object_store.dart';
import '../data/relation_schema_evolution_service.dart';
import '../domain/object_model.dart';
import 'relation_schema_change_impact_dialog.dart';

class RelationPropertySchemaDraft {
  const RelationPropertySchemaDraft({
    required this.targetObjectTypeId,
    required this.multiple,
  });

  final int targetObjectTypeId;
  final bool multiple;
}

/// Runs the complete safe edit flow for an existing Relation Property.
///
/// Presentation collects the proposed target/cardinality, canonical Lane B
/// integrity code inspects the change, the shared impact dialog gathers any
/// explicit multi-to-single choices, and only then does apply execute through
/// [RelationSchemaEvolutionService]. No widget writes Relation config directly.
Future<ObjectPropertyDefinition?> showRelationPropertySchemaEditor({
  required BuildContext context,
  required ObjectPropertyDefinition property,
  required ObjectStore objectStore,
  required RelationSchemaEvolutionService schemaEvolution,
}) async {
  if (!property.isRelation) {
    throw ArgumentError.value(
      property.id,
      'property',
      'Property must be a Relation.',
    );
  }
  final sourceType = await objectStore.getObjectType(property.objectTypeId);
  if (sourceType == null) {
    throw StateError('Relation source ObjectType no longer exists.');
  }
  if (sourceType.kind == ObjectTypeKind.system) {
    throw StateError('System Relation Properties cannot be edited by users.');
  }
  final currentTargetId = property.targetObjectTypeId;
  if (currentTargetId == null) {
    throw StateError('Relation Property has no target ObjectType.');
  }

  final targetTypes = await objectStore.listObjectTypes(sourceType.workspaceId);
  final draft = await showDialog<RelationPropertySchemaDraft>(
    context: context,
    builder: (_) => RelationPropertySchemaEditorDialog(
      property: property,
      targetTypes: targetTypes,
    ),
  );
  if (draft == null) return null;

  final impact = await schemaEvolution.inspectChange(
    property: property,
    targetObjectTypeId: draft.targetObjectTypeId,
    multiple: draft.multiple,
  );
  if (!impact.hasChanges) return impact.property;

  final typeLabels = <int, String>{
    for (final type in targetTypes) type.id: type.name,
  };
  final sourceLabels = <int, String>{
    for (final object in await objectStore.listObjects(property.objectTypeId))
      object.id: object.title,
  };
  final targetLabels = <int, String>{
    for (final object
        in await objectStore.listObjects(draft.targetObjectTypeId))
      object.id: object.title,
  };
  final confirmation = await showRelationSchemaChangeImpactDialog(
    context: context,
    impact: impact,
    currentTargetLabel: typeLabels[impact.currentTargetObjectTypeId] ??
        'ObjectType #${impact.currentTargetObjectTypeId}',
    nextTargetLabel: typeLabels[impact.nextTargetObjectTypeId] ??
        'ObjectType #${impact.nextTargetObjectTypeId}',
    sourceObjectLabels: sourceLabels,
    targetObjectLabels: targetLabels,
  );
  if (confirmation == null) return null;

  return schemaEvolution.updateRelationSchema(
    property: impact.property,
    targetObjectTypeId: draft.targetObjectTypeId,
    multiple: draft.multiple,
    multiToSingleSelections: confirmation.multiToSingleSelections,
  );
}

class RelationPropertySchemaEditorDialog extends StatefulWidget {
  const RelationPropertySchemaEditorDialog({
    super.key,
    required this.property,
    required this.targetTypes,
  });

  final ObjectPropertyDefinition property;
  final List<AppObjectType> targetTypes;

  @override
  State<RelationPropertySchemaEditorDialog> createState() =>
      _RelationPropertySchemaEditorDialogState();
}

class _RelationPropertySchemaEditorDialogState
    extends State<RelationPropertySchemaEditorDialog> {
  late int? _targetObjectTypeId;
  late bool _multiple;

  @override
  void initState() {
    super.initState();
    _targetObjectTypeId = widget.property.targetObjectTypeId;
    _multiple = widget.property.allowsMultipleRelations;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Relation Propertyを編集'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.property.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              key: const ValueKey('relation-property-target-type'),
              initialValue: _targetObjectTypeId,
              decoration: const InputDecoration(labelText: '関連先ObjectType'),
              items: widget.targetTypes
                  .map(
                    (type) => DropdownMenuItem<int>(
                      value: type.id,
                      child: Text(
                        '${type.icon.isEmpty ? '◻️' : type.icon} ${type.name}  '
                        '${type.kind == ObjectTypeKind.system ? '組み込み' : 'カスタム'}',
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) =>
                  setState(() => _targetObjectTypeId = value),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              key: const ValueKey('relation-property-multiple'),
              contentPadding: EdgeInsets.zero,
              title: const Text('複数のObjectを関連付ける'),
              subtitle: Text(_multiple ? 'multi' : 'single'),
              value: _multiple,
              onChanged: (value) => setState(() => _multiple = value),
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
          key: const ValueKey('relation-property-schema-preview'),
          onPressed: _targetObjectTypeId == null
              ? null
              : () => Navigator.pop(
                    context,
                    RelationPropertySchemaDraft(
                      targetObjectTypeId: _targetObjectTypeId!,
                      multiple: _multiple,
                    ),
                  ),
          child: const Text('変更内容を確認'),
        ),
      ],
    );
  }
}
