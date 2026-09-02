import 'package:flutter/material.dart';

import '../data/bidirectional_relation_store.dart';
import '../data/daily_note_service.dart';
import '../data/generic_database_store.dart';
import '../data/object_body_store.dart';
import '../data/object_computed_value_store.dart';
import '../data/object_detail_content_loader.dart';
import '../data/object_detail_edit_service.dart';
import '../data/object_graph_query_store.dart';
import '../data/object_store.dart';
import '../data/object_type_defaults_store.dart';
import '../data/object_value_promotion_execution_service.dart';
import '../data/relation_mutation_service.dart';
import '../data/relation_read_service.dart';
import '../data/system_object_store.dart';
import '../data/weblink_object_service.dart';
import '../data/weblink_value_promotion_service.dart';
import '../domain/object_body_plain_text.dart';
import '../domain/object_detail_content.dart';
import '../domain/object_detail_property_presentation.dart';
import '../domain/object_model.dart';
import '../features/object/presentation/widgets/object_detail_property_view.dart';
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
  static const _propertyPresenter = ObjectDetailPropertyPresenter();

  ObjectGraphNodeRecord? _node;
  ObjectDetailContent? _content;
  RelationNeighborhood _relations = const RelationNeighborhood(
    outgoing: <ResolvedOutgoingRelation>[],
    backlinks: <ResolvedRelationBacklink>[],
  );
  final Set<int> _promotingWeblinkPropertyIds = <int>{};
  bool _loading = true;

  ObjectBodyStore get _bodyStore => ObjectBodyStore(widget.store);

  ObjectDetailContentLoader get _contentLoader => ObjectDetailContentLoader(
        objectStore: widget.objectStore,
        bodyStore: _bodyStore,
        computedStore: ObjectComputedValueStore(widget.objectStore),
      );

  ObjectDetailEditService get _editService => ObjectDetailEditService(
        objectStore: widget.objectStore,
        bodyStore: _bodyStore,
        loader: _contentLoader,
      );

  RelationMutationService get _relationMutations => RelationMutationService(
        objectStore: widget.objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: widget.store,
          objectStore: widget.objectStore,
        ),
        genericStore: widget.store,
      );

  WeblinkValuePromotionService get _weblinkPromotions =>
      WeblinkValuePromotionService(
        weblinks: WeblinkObjectService(
          systemObjects: SystemObjectStore(
            database: widget.store.database,
            objectStore: widget.objectStore,
          ),
          defaultsStore: ObjectTypeDefaultsStore(widget.store),
        ),
        executor: ObjectValuePromotionExecutionService(
          objectStore: widget.objectStore,
          relationMutations: _relationMutations,
        ),
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

  Future<void> _editTitle(
    ObjectGraphNodeRecord node,
    ObjectDetailContent content,
  ) async {
    if (node.isSystemType) return;
    var value = content.object.title;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Object名を変更'),
        content: TextFormField(
          key: const ValueKey('object-title-edit-field'),
          initialValue: value,
          autofocus: true,
          onChanged: (text) => value = text,
          onFieldSubmitted: (_) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const ValueKey('object-title-edit-save'),
            onPressed: () => Navigator.pop(dialogContext, value.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    try {
      final updated = await _editService.rename(
        content: content,
        title: result,
      );
      if (mounted) setState(() => _content = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Object名を変更できませんでした: $error')),
      );
    }
  }

  bool _canEditSimpleValue(
    ObjectGraphNodeRecord node,
    ObjectPropertyDefinition property,
  ) {
    if (node.isSystemType || !property.isValue) return false;
    return property.type == ObjectPropertyType.text ||
        property.type == ObjectPropertyType.url ||
        property.type == ObjectPropertyType.number;
  }

  Future<void> _editSimpleValue(
    ObjectDetailContent content,
    ObjectPropertyDefinition property,
    dynamic current,
  ) async {
    var value = current == null ? '' : '$current';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(property.name),
        content: TextFormField(
          key: ValueKey('object-value-edit-field-${property.id}'),
          initialValue: value,
          autofocus: true,
          keyboardType: property.type == ObjectPropertyType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          onChanged: (text) => value = text,
          onFieldSubmitted: (_) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: ValueKey('object-value-edit-save-${property.id}'),
            onPressed: () => Navigator.pop(dialogContext, value),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;

    dynamic parsed = result;
    if (property.type == ObjectPropertyType.number) {
      if (result.trim().isEmpty) {
        parsed = null;
      } else {
        parsed = num.tryParse(result.trim());
        if (parsed == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数値として解釈できません')),
          );
          return;
        }
      }
    }

    try {
      final updated = await _editService.setValue(
        content: content,
        property: property,
        value: parsed,
      );
      if (mounted) setState(() => _content = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${property.name}を更新できませんでした: $error')),
      );
    }
  }

  bool _canPromoteWeblink(
    ObjectGraphNodeRecord node,
    ObjectPropertyDefinition property,
    dynamic value,
  ) {
    if (node.isSystemType || property.type != ObjectPropertyType.url) {
      return false;
    }
    final raw = value is String ? value.trim() : '';
    final uri = Uri.tryParse(raw);
    return raw.isNotEmpty && uri != null && uri.hasScheme;
  }

  Future<void> _promoteWeblink(
    ObjectDetailContent content,
    ObjectPropertyDefinition property,
    String url,
  ) async {
    if (_promotingWeblinkPropertyIds.contains(property.id)) return;
    setState(() => _promotingWeblinkPropertyIds.add(property.id));
    try {
      final result = await _weblinkPromotions.promote(
        workspaceId: content.objectType.workspaceId,
        sourceObjectId: content.object.id,
        sourceProperty: property,
        url: url,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${result.targetObject.title}」をWeblinkとして関連付けました'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Weblinkに昇格できませんでした: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _promotingWeblinkPropertyIds.remove(property.id));
      }
    }
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  object.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (!node.isSystemType)
                IconButton(
                  key: const ValueKey('object-title-edit-button'),
                  tooltip: 'Object名を変更',
                  onPressed: () => _editTitle(node, content),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 24),
          ...type.properties.map((property) {
            final presentation = _propertyPresenter.present(
              content: content,
              property: property,
            );
            final value = presentation.value;
            final canEditValue = _canEditSimpleValue(node, property);
            final canPromoteWeblink = _canPromoteWeblink(node, property, value);
            final promoting = _promotingWeblinkPropertyIds.contains(property.id);
            return ObjectDetailPropertyView(
              key: ValueKey('object-detail-property-${property.id}'),
              presentation: presentation,
              relationChild: property.isRelation ? _relationValue(property) : null,
              trailing: canEditValue || canPromoteWeblink
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEditValue)
                          IconButton(
                            key: ValueKey('edit-object-value-${property.id}'),
                            tooltip: '${property.name}を編集',
                            onPressed: () =>
                                _editSimpleValue(content, property, value),
                            icon: const Icon(Icons.edit_outlined, size: 17),
                          ),
                        if (canPromoteWeblink)
                          TextButton.icon(
                            key: ValueKey('promote-weblink-${property.id}'),
                            onPressed: promoting
                                ? null
                                : () => _promoteWeblink(
                                      content,
                                      property,
                                      '$value',
                                    ),
                            icon: promoting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                    ),
                                  )
                                : const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Weblinkに昇格'),
                          ),
                      ],
                    )
                  : null,
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
