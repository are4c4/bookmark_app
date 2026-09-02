import 'package:flutter/material.dart';

import '../data/daily_note_service.dart';
import '../data/generic_database_store.dart';
import '../data/object_body_store.dart';
import '../data/object_computed_value_store.dart';
import '../data/object_detail_content_loader.dart';
import '../data/object_graph_query_store.dart';
import '../data/object_store.dart';
import '../data/object_type_defaults_store.dart';
import '../data/relation_read_service.dart';
import '../data/system_object_store.dart';
import '../domain/object_body_plain_text.dart';
import '../domain/object_detail_content.dart';
import '../domain/object_model.dart';
import '../widgets/object_body_section.dart';

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
  static const _bodyAdapter = ObjectBodyPlainTextAdapter();

  ObjectGraphNodeRecord? _node;
  ObjectDetailContent? _content;
  RelationNeighborhood _relations = const RelationNeighborhood(
    outgoing: <ResolvedOutgoingRelation>[],
    backlinks: <ResolvedRelationBacklink>[],
  );
  bool _loading = true;

  ObjectBodyStore get _bodyStore => ObjectBodyStore(widget.store);

  ObjectDetailContentLoader get _contentLoader => ObjectDetailContentLoader(
        objectStore: widget.objectStore,
        bodyStore: _bodyStore,
        computedStore: ObjectComputedValueStore(widget.objectStore),
      );

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

    final content = await _contentLoader.load(
      objectTypeId: node.objectTypeId,
      objectId: node.objectId,
    );
    if (content == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final relations = await RelationReadService(widget.objectStore).neighborhood(
      workspaceId: content.objectType.workspaceId,
      objectTypeId: node.objectTypeId,
      objectId: node.objectId,
    );

    if (!mounted) return;
    setState(() {
      _node = node;
      _content = content;
      _relations = relations;
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

  Future<void> _openToday(ObjectDetailContent content) async {
    final service = DailyNoteService(
      genericStore: widget.store,
      objectStore: widget.objectStore,
      systemObjects: SystemObjectStore(
        database: widget.store.database,
        objectStore: widget.objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(widget.store),
    );
    final note = await service.openOrCreate(
      workspaceId: content.objectType.workspaceId,
    );
    if (!mounted || note.id == widget.objectId) return;
    await _openObject(note.id);
  }

  Future<void> _saveBody(ObjectDetailContent content, String text) async {
    if (!_bodyAdapter.canEdit(content.body)) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final updated = _bodyAdapter.write(
      document: content.body,
      text: text,
      blockIdForIndex: (index) => 'paragraph-${widget.objectId}-$stamp-$index',
    );
    await _bodyStore.write(objectId: widget.objectId, document: updated);
    await _load();
  }

  String _displayValue(ObjectPropertyDefinition property, dynamic value) {
    if (value == null) return 'なし';
    if (value is List) return value.join(', ');
    if (value is bool) return value ? 'はい' : 'いいえ';
    return '$value';
  }

  Widget _relationValue(ObjectPropertyDefinition property) {
    final outgoing = _relations.outgoing
        .where((relation) => relation.property.id == property.id)
        .toList(growable: false);
    if (outgoing.isEmpty) return const Text('なし');
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: outgoing
          .map(
            (relation) => ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.link, size: 16),
              label: Text(relation.targetObject.title),
              onPressed: () => _openObject(relation.targetObject.id),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final node = _node;
    final content = _content;
    if (node == null || content == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Objectが見つかりません')),
      );
    }
    final object = content.object;
    final type = content.objectType;

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
        actions: [
          IconButton(
            tooltip: '今日のノート',
            onPressed: () => _openToday(content),
            icon: const Icon(Icons.today_outlined),
          ),
        ],
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
            final value = content.valueFor(property);
            if (property.config['hidden'] == true) return const SizedBox.shrink();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                property.type == ObjectPropertyType.objectRelation
                    ? Icons.swap_horiz
                    : property.isComputed
                        ? Icons.calculate_outlined
                        : Icons.tune,
                size: 18,
              ),
              title: Text(property.name),
              subtitle: property.isRelation
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _relationValue(property),
                    )
                  : Text(_displayValue(property, value)),
            );
          }),
          ObjectBodySection(
            document: content.body,
            onSave: (text) => _saveBody(content, text),
          ),
          if (_relations.backlinks.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Backlinks  ${_relations.backlinks.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._relations.backlinks.map(
              (backlink) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text(backlink.sourceObject.title),
                subtitle: Text(backlink.property.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openObject(backlink.sourceObject.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
