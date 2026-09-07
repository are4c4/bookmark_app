import 'package:flutter/material.dart';

import '../data/database_view_property_schema_service.dart';
import '../data/database_view_property_type_conversion_service.dart';
import '../data/database_view_property_type_migration_service.dart';
import '../data/object_property_deletion_service.dart';
import '../data/object_store.dart';
import '../data/relation_mutation_service.dart';
import '../data/relation_schema_evolution_service.dart';
import '../domain/object_model.dart';
import 'database_property_schema_editor.dart';
import 'object_property_delete_impact_dialog.dart';

typedef DatabasePropertySchemaManagementError = void Function(
  Object error,
  StackTrace stackTrace,
);

Future<bool?> showDatabasePropertySchemaManagementDialog({
  required BuildContext context,
  required int objectTypeId,
  required ObjectStore objectStore,
  required DatabaseViewPropertySchemaService propertySchema,
  required RelationSchemaEvolutionService relationSchemaEvolution,
  required DatabaseViewPropertyTypeConversionService valueConversion,
  required DatabaseViewPropertyTypeMigrationService valueMigration,
  required RelationMutationService relationMutations,
  VoidCallback? onChanged,
  DatabasePropertySchemaManagementError? onError,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => DatabasePropertySchemaManagementDialog(
      objectTypeId: objectTypeId,
      objectStore: objectStore,
      propertySchema: propertySchema,
      relationSchemaEvolution: relationSchemaEvolution,
      valueConversion: valueConversion,
      valueMigration: valueMigration,
      relationMutations: relationMutations,
      onChanged: onChanged,
      onError: onError,
    ),
  );
}

/// Production-ready schema management surface for one user-owned ObjectType.
///
/// Rename and type editing delegate to their canonical schema services. Delete
/// always runs read-only impact inspection first, may detach only View-owned
/// references explicitly, and then routes ordinary Properties through the
/// Object-owned deletion service or Relation Properties through the canonical
/// Relation lifecycle. No presentation-owned schema/value mutation is used.
class DatabasePropertySchemaManagementDialog extends StatefulWidget {
  const DatabasePropertySchemaManagementDialog({
    super.key,
    required this.objectTypeId,
    required this.objectStore,
    required this.propertySchema,
    required this.relationSchemaEvolution,
    required this.valueConversion,
    required this.valueMigration,
    required this.relationMutations,
    this.onChanged,
    this.onError,
  });

  final int objectTypeId;
  final ObjectStore objectStore;
  final DatabaseViewPropertySchemaService propertySchema;
  final RelationSchemaEvolutionService relationSchemaEvolution;
  final DatabaseViewPropertyTypeConversionService valueConversion;
  final DatabaseViewPropertyTypeMigrationService valueMigration;
  final RelationMutationService relationMutations;
  final VoidCallback? onChanged;
  final DatabasePropertySchemaManagementError? onError;

  @override
  State<DatabasePropertySchemaManagementDialog> createState() =>
      _DatabasePropertySchemaManagementDialogState();
}

class _DatabasePropertySchemaManagementDialogState
    extends State<DatabasePropertySchemaManagementDialog> {
  AppObjectType? _objectType;
  bool _loading = true;
  bool _mutating = false;
  bool _failed = false;

  ObjectPropertyDeletionService get _ordinaryDeletion =>
      ObjectPropertyDeletionService(
        genericStore: widget.propertySchema.genericStore,
        objectStore: widget.objectStore,
      );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final type = await widget.objectStore.getObjectType(widget.objectTypeId);
      if (!mounted) return;
      setState(() {
        _objectType = type;
        _loading = false;
        _failed = type == null;
      });
    } catch (error, stackTrace) {
      widget.onError?.call(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _rename(ObjectPropertyDefinition property) async {
    final name = await _askName(property);
    if (name == null || name == property.name) return;
    await _runMutation(() async {
      await widget.propertySchema.renameProperty(
        objectTypeId: widget.objectTypeId,
        propertyId: property.id,
        name: name,
      );
    });
  }

  Future<String?> _askName(ObjectPropertyDefinition property) async {
    var value = property.name;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('プロパティ名を変更'),
        content: TextFormField(
          key: ValueKey('property-schema-rename-input-${property.id}'),
          initialValue: property.name,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名前'),
          onChanged: (next) => value = next,
          onFieldSubmitted: (_) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: ValueKey('property-schema-rename-submit-${property.id}'),
            onPressed: () => Navigator.pop(dialogContext, value),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final trimmed = result?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _delete(ObjectPropertyDefinition property) async {
    if (_mutating) return;
    try {
      var impact = await widget.propertySchema.inspectDelete(
        objectTypeId: widget.objectTypeId,
        propertyId: property.id,
      );
      if (!mounted) return;
      final confirmed = await showObjectPropertyDeleteImpactDialog(
        context,
        impact: impact,
        onDetachViewReferences: impact.isReferencedByViews
            ? () async {
                await widget.propertySchema.detachViewReferences(
                  objectTypeId: widget.objectTypeId,
                  propertyId: property.id,
                );
                impact = await widget.propertySchema.inspectDelete(
                  objectTypeId: widget.objectTypeId,
                  propertyId: property.id,
                );
                return impact;
              }
            : null,
      );
      if (confirmed != true) return;
      await _runMutation(() async {
        if (property.isRelation) {
          await widget.relationMutations.deleteRelationProperty(property);
        } else {
          await _ordinaryDeletion.deleteProperty(property);
        }
      });
    } catch (error, stackTrace) {
      widget.onError?.call(error, stackTrace);
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() {
      _mutating = true;
      _failed = false;
    });
    try {
      await action();
      widget.onChanged?.call();
      await _reload();
    } catch (error, stackTrace) {
      widget.onError?.call(error, stackTrace);
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _objectType;
    return AlertDialog(
      title: const Text('プロパティ設定'),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : type == null
                ? const Text('ObjectTypeを読み込めませんでした。')
                : type.kind == ObjectTypeKind.system
                    ? const Text('システムObjectTypeのプロパティはここでは変更できません。')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_failed) ...[
                            Text(
                              'プロパティを更新できませんでした。内容を確認して再試行してください。',
                              key: const ValueKey('property-schema-management-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 420),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: type.properties.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final property = type.properties[index];
                                return ListTile(
                                  key: ValueKey(
                                    'property-schema-management-${property.id}',
                                  ),
                                  dense: true,
                                  title: Text(property.name),
                                  subtitle: Text(_typeLabel(property.type)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        key: ValueKey(
                                          'property-schema-rename-${property.id}',
                                        ),
                                        tooltip: '名前を変更',
                                        onPressed: _mutating
                                            ? null
                                            : () => _rename(property),
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                      ),
                                      DatabasePropertySchemaEditButton(
                                        property: property,
                                        objectStore: widget.objectStore,
                                        relationSchemaEvolution:
                                            widget.relationSchemaEvolution,
                                        valueConversion: widget.valueConversion,
                                        valueMigration: widget.valueMigration,
                                        onChanged: (_) {
                                          widget.onChanged?.call();
                                          _reload();
                                        },
                                        tooltip: '型・Relation設定を編集',
                                      ),
                                      IconButton(
                                        key: ValueKey(
                                          'property-schema-delete-${property.id}',
                                        ),
                                        tooltip: '削除',
                                        onPressed: _mutating
                                            ? null
                                            : () => _delete(property),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: _mutating ? null : () => Navigator.pop(context, true),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  static String _typeLabel(ObjectPropertyType type) => switch (type) {
        ObjectPropertyType.text => 'Text',
        ObjectPropertyType.number => 'Number',
        ObjectPropertyType.checkbox => 'Checkbox',
        ObjectPropertyType.date => 'Date',
        ObjectPropertyType.url => 'URL',
        ObjectPropertyType.select => 'Select',
        ObjectPropertyType.multiSelect => 'Multi-select',
        ObjectPropertyType.rating => 'Rating',
        ObjectPropertyType.objectRelation => 'Relation',
        ObjectPropertyType.formula => 'Formula',
        ObjectPropertyType.rollup => 'Rollup',
        ObjectPropertyType.title => 'Title',
        ObjectPropertyType.image => 'Image',
        ObjectPropertyType.file => 'File',
        ObjectPropertyType.createdTime => 'Created time',
        ObjectPropertyType.updatedTime => 'Updated time',
      };
}
