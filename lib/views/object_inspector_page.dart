import 'package:flutter/material.dart';

import '../data/generic_database_store.dart';
import '../data/object_body_store.dart';
import '../data/object_computed_value_store.dart';
import '../data/object_detail_content_loader.dart';
import '../data/object_detail_session_loader.dart';
import '../data/object_graph_query_store.dart';
import '../data/object_store.dart';
import '../data/object_type_defaults_service.dart';
import '../data/object_type_defaults_store.dart';
import '../domain/object_detail_session.dart';
import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';

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
  ObjectDetailSession? _session;
  List<ObjectGraphBacklinkRecord> _backlinks = const [];
  Map<int, ObjectGraphNodeRecord> _relatedNodes = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ObjectDetailSessionLoader _sessionLoader() {
    final bodyStore = ObjectBodyStore(widget.store);
    final defaultsStore = ObjectTypeDefaultsStore(widget.store);
    return ObjectDetailSessionLoader(
      contentLoader: ObjectDetailContentLoader(
        objectStore: widget.objectStore,
        bodyStore: bodyStore,
        computedStore: ObjectComputedValueStore(widget.objectStore),
      ),
      defaultsService: ObjectTypeDefaultsService(store: defaultsStore),
      appFallback: const ObjectTypeDefaults(openMode: ObjectOpenMode.fullPage),
    );
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final graph = ObjectGraphQueryStore(widget.store);
    final node = await graph.getNode(widget.objectId);
    if (node == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final session = await _sessionLoader().load(
      objectTypeId: node.objectTypeId,
      objectId: node.objectId,
    );
    final backlinks = await graph.backlinks(node.objectId);
    final relatedNodes = <int, ObjectGraphNodeRecord>{};
    if (session != null) {
      final content = session.content;
      for (final property in content.objectType.properties) {
        if (!property.isRelation) continue;
        for (final targetId in ObjectRelationValue.fromJson(
          content.object.valueFor(property.id),
        ).objectIds) {
          final target = await graph.getNode(targetId);
          if (target != null) relatedNodes[targetId] = target;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _node = node;
      _session = session;
      _backlinks = backlinks;
      _relatedNodes = relatedNodes;
      _loading = false;
    });
  }

  Future<void> _openObject(int objectId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ObjectInspectorPage(
          store: widget.store,
          objectStore: widget.objectStore,
          objectId: objectId,
        ),
      ),
    );
  }

  String _displayValue(ObjectPropertyDefinition property, dynamic value) {
    if (value == null) return 'なし';
    if (value is List) return value.join(', ');
    if (value is bool) return value ? 'はい' : 'いいえ';
    return '$value';
  }

  Widget _relationValue(ObjectPropertyDefinition property, dynamic value) {
    final ids = ObjectRelationValue.fromJson(value).objectIds;
    if (ids.isEmpty) return const Text('なし');
    final nodes = ids
        .map((id) => _relatedNodes[id])
        .whereType<ObjectGraphNodeRecord>()
        .toList(growable: false);
    if (nodes.isEmpty) return Text('${ids.length}件のObject');
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: nodes
          .map(
            (node) => ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: Text(node.objectTypeIcon),
              label: Text(node.title),
              onPressed: () => _openObject(node.objectId),
            ),
          )
          .toList(),
    );
  }

  List<ObjectPropertyDefinition> _visibleProperties(ObjectDetailSession session) {
    final properties = session.content.objectType.properties
        .where((property) => property.config['hidden'] != true)
        .toList(growable: false);
    final visibleIds = session.defaults.visiblePropertyIds;
    final filtered = visibleIds.isEmpty
        ? properties.toList()
        : properties
            .where((property) => visibleIds.contains(property.id))
            .toList();
    final order = session.defaults.propertyOrder;
    if (order.isEmpty) return filtered;
    final rank = <int, int>{
      for (var index = 0; index < order.length; index++) order[index]: index,
    };
    filtered.sort((a, b) {
      final aRank = rank[a.id];
      final bRank = rank[b.id];
      if (aRank != null && bRank != null) return aRank.compareTo(bRank);
      if (aRank != null) return -1;
      if (bRank != null) return 1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return filtered;
  }

  List<Widget> _bodyWidgets(ObjectDetailSession session) {
    final blocks = session.content.body.blocks;
    if (blocks.isEmpty) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 12),
      Text(
        'Body',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      ...blocks.map((block) {
        if (block.type == 'paragraph') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SelectableText(block.text ?? ''),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.extension_outlined),
            title: Text(block.type),
            subtitle: const Text('このBlockは現在のInspectorでは読み取り専用です'),
          ),
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final node = _node;
    final session = _session;
    if (node == null || session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Objectが見つかりません')),
      );
    }
    final content = session.content;
    final object = content.object;

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
          ..._visibleProperties(session).map((property) {
            final value = content.valueFor(property);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                property.isRelation ? Icons.swap_horiz : Icons.tune,
                size: 18,
              ),
              title: Text(property.name),
              subtitle: property.isRelation
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _relationValue(property, value),
                    )
                  : Text(_displayValue(property, value)),
            );
          }),
          ..._bodyWidgets(session),
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
                onTap: () => _openObject(backlink.sourceObjectId),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
