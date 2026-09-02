import 'package:flutter/material.dart';

import '../data/generic_database_store.dart';
import '../data/object_body_store.dart';
import '../data/object_computed_value_store.dart';
import '../data/object_detail_content_loader.dart';
import '../data/object_graph_query_store.dart';
import '../data/object_store.dart';
import '../domain/object_body_plain_text.dart';
import '../domain/object_detail_content.dart';
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
  static const _bodyAdapter = ObjectBodyPlainTextAdapter();

  ObjectGraphNodeRecord? _node;
  ObjectDetailContent? _content;
  List<ObjectGraphBacklinkRecord> _backlinks = const [];
  Map<int, ObjectGraphNodeRecord> _relatedNodes = const {};
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

    final backlinks = await graph.backlinks(node.objectId);
    final relatedNodes = <int, ObjectGraphNodeRecord>{};
    for (final property in content.objectType.properties) {
      if (!property.isRelation) continue;
      for (final targetId in ObjectRelationValue.fromJson(
        content.object.values[property.id],
      ).objectIds) {
        final target = await graph.getNode(targetId);
        if (target != null) relatedNodes[targetId] = target;
      }
    }

    if (!mounted) return;
    setState(() {
      _node = node;
      _content = content;
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

  Future<void> _editBody(ObjectDetailContent content) async {
    if (!_bodyAdapter.canEdit(content.body)) return;

    final controller = TextEditingController(text: _bodyAdapter.read(content.body));
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('本文を編集'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 8,
            maxLines: 18,
            decoration: const InputDecoration(
              hintText: '本文を書き始める…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final updated = _bodyAdapter.write(
      document: content.body,
      text: result,
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

  Widget _bodySection(ObjectDetailContent content) {
    final editable = _bodyAdapter.canEdit(content.body);
    final paragraphs = editable ? _bodyAdapter.read(content.body) : null;
    final hasText = paragraphs?.trim().isNotEmpty == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '本文',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (editable)
              TextButton.icon(
                onPressed: () => _editBody(content),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text(hasText ? '編集' : '書き始める'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!editable)
          const Text(
            'この本文にはリッチブロックが含まれています。対応エディタが追加されるまで、内容を保護するため簡易編集は無効です。',
          )
        else if (!hasText)
          Text(
            '本文はまだありません。',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          )
        else
          SelectableText(
            paragraphs!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
      ],
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
                      child: _relationValue(property, value),
                    )
                  : Text(_displayValue(property, value)),
            );
          }),
          _bodySection(content),
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
