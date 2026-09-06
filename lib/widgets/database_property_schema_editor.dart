import 'package:flutter/material.dart';

import '../data/database_view_property_type_conversion_service.dart';
import '../data/database_view_property_type_migration_service.dart';
import '../data/object_store.dart';
import '../data/relation_schema_evolution_service.dart';
import '../domain/object_model.dart';
import 'relation_property_schema_editor.dart';
import 'value_property_schema_editor.dart';

/// Routes one persisted user-owned Property to the correct safe schema editor.
///
/// Relation target/cardinality changes remain owned by
/// [RelationSchemaEvolutionService]. Ordinary Value type changes use the
/// Database/View preflight + transactional migration path. Computed and managed
/// primitive Properties are intentionally not retyped through this generic UX.
Future<ObjectPropertyDefinition?> showDatabasePropertySchemaEditor({
  required BuildContext context,
  required ObjectPropertyDefinition property,
  required ObjectStore objectStore,
  required RelationSchemaEvolutionService relationSchemaEvolution,
  required DatabaseViewPropertyTypeConversionService valueConversion,
  required DatabaseViewPropertyTypeMigrationService valueMigration,
}) {
  if (property.isRelation) {
    return showRelationPropertySchemaEditor(
      context: context,
      property: property,
      objectStore: objectStore,
      schemaEvolution: relationSchemaEvolution,
    );
  }
  if (_isEditableValueType(property.type)) {
    return showValuePropertySchemaEditor(
      context: context,
      property: property,
      objectStore: objectStore,
      conversion: valueConversion,
      migration: valueMigration,
    );
  }
  throw UnsupportedError(
    'This Property does not support generic schema editing.',
  );
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

/// Compact action that lets a Database host expose safe Property schema editing
/// without duplicating dispatch or migration logic.
class DatabasePropertySchemaEditButton extends StatelessWidget {
  const DatabasePropertySchemaEditButton({
    super.key,
    required this.property,
    required this.objectStore,
    required this.relationSchemaEvolution,
    required this.valueConversion,
    required this.valueMigration,
    required this.onChanged,
    this.tooltip = 'プロパティ設定を編集',
  });

  final ObjectPropertyDefinition property;
  final ObjectStore objectStore;
  final RelationSchemaEvolutionService relationSchemaEvolution;
  final DatabaseViewPropertyTypeConversionService valueConversion;
  final DatabaseViewPropertyTypeMigrationService valueMigration;
  final ValueChanged<ObjectPropertyDefinition> onChanged;
  final String tooltip;

  bool get _supported =>
      property.isRelation || _isEditableValueType(property.type);

  @override
  Widget build(BuildContext context) => IconButton(
        key: ValueKey('database-property-schema-edit-${property.id}'),
        tooltip: _supported ? tooltip : 'このプロパティの型は編集できません',
        icon: const Icon(Icons.settings_outlined, size: 17),
        onPressed: !_supported
            ? null
            : () async {
                final changed = await showDatabasePropertySchemaEditor(
                  context: context,
                  property: property,
                  objectStore: objectStore,
                  relationSchemaEvolution: relationSchemaEvolution,
                  valueConversion: valueConversion,
                  valueMigration: valueMigration,
                );
                if (changed != null) onChanged(changed);
              },
      );
}
