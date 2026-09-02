import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../domain/object_model.dart';

class ObjectInspectorPage extends StatefulWidget {
  const ObjectInspectorPage({
    super.key,
    required this.store,
    required this.objectStore,
    required this.objectId,
  });

  final GenericDatabaseStore store;
  final ObjectStore objectStore;
  final int objectId;

  @override
  State<ObjectInspectorPage> createState() => _ObjectInspectorPageState();
}

class _ObjectInspectorPageState extends State<ObjectInspectorPage> {
  AppObjectType? _type;
  AppObject? _object;
  List<_InspectorBacklink> _backlinks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final workspaceId = await _workspaceIdForObject();
    if (workspaceId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final types = await widget.objectStore.listObjectTypes(workspaceId);
    final objectsByType = <int, List<AppObject>>{};
    AppObjectType? foundType;
    AppObject? foundObject;
    for (final type in types) {
      final objects = await widget.objectStore.listObjects(type.id);
      objectsByType[type.id] = objects;
      for (final object in objects) {
        if (object.id == widget.objectId) {
          foundType = type;
          foundObject = object;
          break;
        }
      }
    }

    final backlinks = <_InspectorBacklink>[];
    if (foundObject != null) {
      final edges = await widget.objectStore.backlinks(foundObject.id);
      for (final edge in edges) {
        AppObject? source;
        AppObjectType? sourceType;
        ObjectPropertyDefinition? property;
        for (final type in types) {
          for (final candidate in type.properties) {
            if (candidate.id == edge.propertyId) property = candidate;
          }
          final objects = objectsByType[type.id] ?? const <AppObject>[];
          for (final candidate in objects) {
            if (candidate.id == edge.sourceObjectId) {
              source = candidate;
              sourceType = type;
              break;
            }
          }
          if (source != null) break;
        }
        if (source != null && sourceType != null) {
          backlinks.add(_InspectorBacklink(
            source: source,
            sourceType: sourceType,
            property: property,
          ));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _type = foundType;
      _object = foundObject;
      _backlinks = backlinks;
      _loading = false;
    });
  }

  Future<int?> _workspaceIdForObject() async {
    final row = await widget.store.database.customSelect(
      '''SELECT gd.workspace_id
         FROM generic_records gr
         JOIN generic_databases gd ON gd.id = gr.database_id
         WHERE gr.id = ? LIMIT 1''',
      variables: [Variable<int>(widget.objectId)],
    ).getSingleOrNull();
    return row?.read<int>('workspace_id');
  }

  String _displayValue(ObjectPropertyDefinition property, dynamic value) {
    if (value == null) return 'なし';
    if (property.type == ObjectPropertyType.objectRelation) {
      final ids = ObjectRelationValue.fromJson(value).objectIds;
      return ids.isEmpty ? 'なし' : '${ids.length}件のObject';
    }
    if (value is List) return value.join(', ');
    if (value is bool) return value ? 'はい' : 'いいえ';
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final object = _object;
    final type = _type;
    if (object == null || type == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Objectが見つかりません')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type.icon),
            const SizedBox(width: 8),
            Text(type.name),
            if (type.kind == ObjectTypeKind.system) ...[
              const SizedBox(width: 8),
              const Chip(label: Text('System')),
            ],
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        children: [
          Text(
            object.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 24),
          ...type.properties.map((property) {
            final value = object.values[property.id];
            if (property.config['hidden'] == true) return const SizedBox.shrink();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                property.type == ObjectPropertyType.objectRelation
                    ? Icons.swap_horiz
                    : Icons.tune,
                size: 18,
              ),
              title: Text(property.name),
              subtitle: Text(_displayValue(property, value)),
            );
          }),
          if (_backlinks.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Backlinks  ${_backlinks.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._backlinks.map((backlink) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(backlink.sourceType.icon),
                  title: Text(backlink.source.title),
                  subtitle: Text(
                    backlink.property == null
                        ? backlink.sourceType.name
                        : '${backlink.sourceType.name} · ${backlink.property!.name}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ObjectInspectorPage(
                        store: widget.store,
                        objectStore: widget.objectStore,
                        objectId: backlink.source.id,
                      ),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _InspectorBacklink {
  const _InspectorBacklink({
    required this.source,
    required this.sourceType,
    required this.property,
  });

  final AppObject source;
  final AppObjectType sourceType;
  final ObjectPropertyDefinition? property;
}
