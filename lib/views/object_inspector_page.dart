import 'package:flutter/material.dart';

import '../data/generic_database_store.dart';
import '../data/object_graph_query_store.dart';
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
  ObjectGraphNodeRecord? _node;
  AppObjectType? _type;
  AppObject? _object;
  List<ObjectGraphBacklinkRecord> _backlinks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final graph = ObjectGraphQueryStore(widget.store);
    final node = await graph.getNode(widget.objectId);
    if (node == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final type = await widget.objectStore.getObjectType(node.objectTypeId);
    final objects = await widget.objectStore.listObjects(node.objectTypeId);
    AppObject? object;
    for (final candidate in objects) {
      if (candidate.id == node.objectId) {
        object = candidate;
        break;
      }
    }
    final backlinks = await graph.backlinks(node.objectId);

    if (!mounted) return;
    setState(() {
      _node = node;
      _type = type;
      _object = object;
      _backlinks = backlinks;
      _loading = false;
    });
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
    final node = _node;
    final object = _object;
    final type = _type;
    if (node == null || object == null || type == null) {
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
            Text(node.objectTypeIcon),
            const SizedBox(width: 8),
            Text(node.objectTypeName),
            if (node.isSystemType) ...[
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
            ..._backlinks.map(
              (backlink) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(backlink.sourceObjectTypeIcon),
                title: Text(backlink.sourceTitle),
                subtitle: Text(
                  '${backlink.sourceObjectTypeName} · ${backlink.propertyName}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ObjectInspectorPage(
                      store: widget.store,
                      objectStore: widget.objectStore,
                      objectId: backlink.sourceObjectId,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
