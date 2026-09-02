import 'package:flutter/material.dart';

import '../data/database_collection_config_service.dart';
import '../domain/object_model.dart';
import '../domain/object_query.dart';
import 'object_query_dialog.dart';

class DatabaseCollectionSettingsDraft {
  const DatabaseCollectionSettingsDraft({
    required this.targetObjectTypeId,
    required this.collectionFilter,
  });

  final int targetObjectTypeId;
  final List<ObjectFilterRule> collectionFilter;
}

Future<DatabaseCollectionSettingsDraft?> showDatabaseCollectionSettingsDialog(
  BuildContext context, {
  required DatabaseCollectionConfigContext config,
}) {
  return showDialog<DatabaseCollectionSettingsDraft>(
    context: context,
    builder: (_) => DatabaseCollectionSettingsDialog(config: config),
  );
}

class DatabaseCollectionSettingsDialog extends StatefulWidget {
  const DatabaseCollectionSettingsDialog({
    super.key,
    required this.config,
  });

  final DatabaseCollectionConfigContext config;

  @override
  State<DatabaseCollectionSettingsDialog> createState() =>
      _DatabaseCollectionSettingsDialogState();
}

class _DatabaseCollectionSettingsDialogState
    extends State<DatabaseCollectionSettingsDialog> {
  late int _targetObjectTypeId;
  late List<ObjectFilterRule> _filters;

  @override
  void initState() {
    super.initState();
    _targetObjectTypeId = widget.config.definition.targetObjectTypeId;
    _filters = [...widget.config.definition.collectionFilter];
  }

  AppObjectType get _targetObjectType => widget.config.availableObjectTypes
      .singleWhere((type) => type.id == _targetObjectTypeId);

  Future<void> _editFilters() async {
    final result = await showObjectQueryDialog(
      context,
      properties: _targetObjectType.properties,
      initialFilters: _filters,
    );
    if (result == null || !mounted) return;
    setState(() => _filters = [...result.filters]);
  }

  void _changeTarget(int? nextId) {
    if (nextId == null || nextId == _targetObjectTypeId) return;
    setState(() {
      _targetObjectTypeId = nextId;
      // Property ids are scoped to an ObjectType. Keeping filters from the old
      // target would either fail validation or accidentally point elsewhere.
      _filters = const <ObjectFilterRule>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetObjectType;
    return AlertDialog(
      title: const Text('データベースのコレクション'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'この設定は「どのObjectがデータベースに属するか」を決めます。'
              'Viewのフィルターとは別に保存されます。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: const ValueKey('collection-target-object-type'),
              initialValue: _targetObjectTypeId,
              decoration: const InputDecoration(labelText: 'ObjectType'),
              items: widget.config.availableObjectTypes
                  .map(
                    (type) => DropdownMenuItem<int>(
                      value: type.id,
                      child: Text('${type.icon} ${type.name}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _changeTarget,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('コレクション条件'),
              subtitle: Text(
                _filters.isEmpty ? 'すべての${target.name} Object' : '${_filters.length}件の条件',
              ),
              trailing: TextButton.icon(
                key: const ValueKey('edit-collection-filters'),
                onPressed: _editFilters,
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('条件を編集'),
              ),
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
          key: const ValueKey('save-collection-settings'),
          onPressed: () => Navigator.pop(
            context,
            DatabaseCollectionSettingsDraft(
              targetObjectTypeId: _targetObjectTypeId,
              collectionFilter: List<ObjectFilterRule>.unmodifiable(_filters),
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
