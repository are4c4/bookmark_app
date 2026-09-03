import 'package:flutter/material.dart';

import '../data/bidirectional_relation_store.dart';
import '../data/daily_note_detail_navigation_service.dart';
import '../data/daily_note_navigation_service.dart';
import '../data/daily_note_service.dart';
import '../data/generic_database_store.dart';
import '../data/object_body_block_action_controller.dart';
import '../data/object_body_block_duplicate_service.dart';
import '../data/object_body_block_edit_service.dart';
import '../data/object_body_reference_insert_controller.dart';
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
import '../domain/object_body.dart';
import '../domain/object_body_block_actions.dart';
import '../domain/object_body_block_contracts.dart';
import '../domain/object_body_block_identity.dart';
import '../domain/object_body_reference_insert.dart';
import '../domain/object_detail_content.dart';
import '../domain/object_detail_property_presentation.dart';
import '../domain/object_model.dart';
import '../features/object/presentation/widgets/daily_note_navigation_bar.dart';
import '../features/object/presentation/widgets/object_body_block_action_bar.dart';
import '../features/object/presentation/widgets/object_body_document_view.dart';
import '../features/object/presentation/widgets/object_body_insert_menu_button.dart';
import '../features/object/presentation/widgets/object_body_object_reference_picker.dart';
import '../features/object/presentation/widgets/object_body_reference_insert_menu_button.dart';
import '../features/object/presentation/widgets/object_detail_property_view.dart';

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
  static const _propertyPresenter = ObjectDetailPropertyPresenter();
  static const _bodyBlockIds = ObjectBodyBlockIdAllocator();

  ObjectGraphNodeRecord? _node;
  ObjectDetailContent? _content;
  RelationNeighborhood _relations = const RelationNeighborhood(
    outgoing: <ResolvedOutgoingRelation>[],
    backlinks: <ResolvedRelationBacklink>[],
  );
  final Set<int> _promotingWeblinkPropertyIds = <int>{};
  String? _systemKey;
  bool _loading = true;
  bool _dailyNoteNavigating = false;

  ObjectBodyStore get _bodyStore => ObjectBodyStore(widget.store);

  SystemObjectStore get _systemObjects => SystemObjectStore(
        database: widget.store.database,
        objectStore: widget.objectStore,
      );

  DailyNoteService get _dailyNotes => DailyNoteService(
        genericStore: widget.store,
        objectStore: widget.objectStore,
        systemObjects: _systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(widget.store),
      );

  DailyNoteDetailNavigationService get _dailyNoteNavigation =>
      DailyNoteDetailNavigationService(
        navigation: DailyNoteNavigationService(_dailyNotes),
        detailLoader: _contentLoader,
      );

  ObjectBodyBlockEditService get _bodyBlockEdits =>
      ObjectBodyBlockEditService(bodyStore: _bodyStore);

  ObjectBodyBlockActionController get _bodyActions =>
      ObjectBodyBlockActionController(editService: _bodyBlockEdits);

  ObjectBodyBlockDuplicateService get _bodyDuplicates =>
      ObjectBodyBlockDuplicateService(editService: _bodyBlockEdits);

  ObjectBodyReferenceInsertController get _bodyReferenceInserts =>
      ObjectBodyReferenceInsertController(editService: _bodyBlockEdits);

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
          systemObjects: _systemObjects,
          defaultsStore: ObjectTypeDefaultsStore(widget.store),
        ),
        executor: ObjectValuePromotionExecutionService(
          objectStore: widget.objectStore,
          relationMutations: _relationMutations,
        ),
      );

  bool get _isDailyNote => _systemKey == DailyNoteService.systemKey;

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

    final systemKey = await _systemObjects.systemKeyForObjectType(node.objectTypeId);
    final relations = await RelationReadService(widget.objectStore).neighborhood(
      workspaceId: content.objectType.workspaceId,
      objectTypeId: node.objectTypeId,
      objectId: node.objectId,
    );

    if (!mounted) return;
    setState(() {
      _node = node;
      _content = content;
      _systemKey = systemKey;
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

  Future<void> _navigateDailyNote(
    Future<ObjectDetailContent> Function(DailyNoteDetailNavigationService service)
        open,
  ) async {
    if (_dailyNoteNavigating) return;
    setState(() => _dailyNoteNavigating = true);
    try {
      final target = await open(_dailyNoteNavigation);
      if (!mounted || target.object.id == widget.objectId) return;
      await _openObject(target.object.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Daily Noteを開けませんでした: $error')),
      );
    } finally {
      if (mounted) setState(() => _dailyNoteNavigating = false);
    }
  }

  Future<void> _openToday(ObjectDetailContent content) => _navigateDailyNote(
        (service) => service.openToday(
          workspaceId: content.objectType.workspaceId,
        ),
      );

  DateTime? _dailyNoteDate(ObjectDetailContent content) {
    for (final property in content.objectType.properties) {
      if (property.name != 'Date' || property.type != ObjectPropertyType.date) {
        continue;
      }
      final value = content.object.valueFor(property.id);
      if (value is DateTime) {
        return DateTime(value.year, value.month, value.day);
      }
      final parsed = DateTime.tryParse('${value ?? ''}');
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return null;
  }

  bool _canEditBody(ObjectGraphNodeRecord node) =>
      !node.isSystemType || _isDailyNote;

  void _applyBodyDocument(ObjectBodyDocument document) {
    final current = _content;
    if (mounted && current != null) {
      setState(() => _content = current.copyWith(body: document));
    }
  }

  Future<void> _runBodyMutation(
    Future<ObjectBodyDocument> Function() mutation,
  ) async {
    try {
      _applyBodyDocument(await mutation());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bodyを更新できませんでした: $error')),
      );
    }
  }

  Future<void> _editBodyText(ObjectBodyBlock block, String text) =>
      _runBodyMutation(
        () => _bodyBlockEdits.updateText(
          objectId: widget.objectId,
          blockId: block.id,
          text: text,
        ),
      );

  Future<void> _toggleChecklist(ObjectBodyBlock block, bool checked) =>
      _runBodyMutation(
        () => _bodyBlockEdits.setChecklistChecked(
          objectId: widget.objectId,
          blockId: block.id,
          checked: checked,
        ),
      );

  Future<void> _insertBodyBlock(
    ObjectBodyInsertKind kind, {
    String? afterBlockId,
  }) async {
    final latest = await _bodyStore.read(widget.objectId);
    final newBlockId = _bodyBlockIds.next(latest, prefix: kind.name);
    await _runBodyMutation(
      () => afterBlockId == null
          ? _bodyActions.insert(
              objectId: widget.objectId,
              newBlockId: newBlockId,
              kind: kind,
            )
          : _bodyActions.insertAfter(
              objectId: widget.objectId,
              anchorBlockId: afterBlockId,
              newBlockId: newBlockId,
              kind: kind,
            ),
    );
  }

  Future<List<ObjectBodyObjectReferenceCandidate>> _objectReferenceCandidates(
    ObjectDetailContent content,
  ) async {
    final candidates = <ObjectBodyObjectReferenceCandidate>[];
    final objectTypes = await widget.objectStore.listObjectTypes(
      content.objectType.workspaceId,
    );
    for (final objectType in objectTypes) {
      final objects = await widget.objectStore.listObjects(objectType.id);
      for (final object in objects) {
        candidates.add(
          ObjectBodyObjectReferenceCandidate(
            objectId: object.id,
            title: object.title,
            objectTypeName: objectType.name,
            objectTypeIcon: objectType.icon,
          ),
        );
      }
    }
    candidates.sort((a, b) {
      final typeOrder = a.objectTypeName.compareTo(b.objectTypeName);
      return typeOrder != 0 ? typeOrder : a.title.compareTo(b.title);
    });
    return candidates;
  }

  Future<void> _insertObjectReference(
    ObjectDetailContent content, {
    String? afterBlockId,
  }) async {
    try {
      final candidates = await _objectReferenceCandidates(content);
      if (!mounted) return;
      final targetId = await showObjectBodyObjectReferencePicker(
        context,
        candidates: candidates,
      );
      if (targetId == null) return;
      final target = candidates.firstWhere(
        (candidate) => candidate.objectId == targetId,
      );
      final request = ObjectBodyObjectReferenceInsert(
        objectId: target.objectId,
        label: target.title,
      );
      final result = afterBlockId == null
          ? await _bodyReferenceInserts.insertAllocated(
              objectId: widget.objectId,
              request: request,
            )
          : await _bodyReferenceInserts.insertAfterAllocated(
              objectId: widget.objectId,
              anchorBlockId: afterBlockId,
              request: request,
            );
      _applyBodyDocument(result.document);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Object参照を追加できませんでした: $error')),
      );
    }
  }

  Future<void> _moveBodyBlockUp(ObjectBodyBlock block) => _runBodyMutation(
        () => _bodyActions.moveUp(
          objectId: widget.objectId,
          blockId: block.id,
        ),
      );

  Future<void> _moveBodyBlockDown(ObjectBodyBlock block) => _runBodyMutation(
        () => _bodyActions.moveDown(
          objectId: widget.objectId,
          blockId: block.id,
        ),
      );

  Future<void> _deleteBodyBlock(ObjectBodyBlock block) => _runBodyMutation(
        () => _bodyActions.remove(
          objectId: widget.objectId,
          blockId: block.id,
        ),
      );

  Future<void> _duplicateBodyBlock(ObjectBodyBlock block) async {
    try {
      final result = await _bodyDuplicates.duplicateAfter(
        objectId: widget.objectId,
        sourceBlockId: block.id,
      );
      _applyBodyDocument(result.document);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bodyを更新できませんでした: $error')),
      );
    }
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
    final dailyNoteDate = _isDailyNote ? _dailyNoteDate(content) : null;
    final canEditBody = _canEditBody(node);

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
            onPressed: _dailyNoteNavigating ? null : () => _openToday(content),
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
          if (dailyNoteDate != null) ...[
            const SizedBox(height: 12),
            DailyNoteNavigationBar(
              currentDate: dailyNoteDate,
              enabled: !_dailyNoteNavigating,
              onPrevious: () => _navigateDailyNote(
                (service) => service.openPrevious(
                  workspaceId: content.objectType.workspaceId,
                  currentDate: dailyNoteDate,
                ),
              ),
              onToday: () => _openToday(content),
              onNext: () => _navigateDailyNote(
                (service) => service.openNext(
                  workspaceId: content.objectType.workspaceId,
                  currentDate: dailyNoteDate,
                ),
              ),
            ),
          ],
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
          const SizedBox(height: 24),
          Text(
            'Body',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ObjectBodyDocumentView(
            document: content.body,
            onTextChanged: canEditBody
                ? (block, text) => _editBodyText(block, text)
                : null,
            onChecklistChanged: canEditBody
                ? (block, checked) => _toggleChecklist(block, checked)
                : null,
            onObjectReferenceTap: (block) {
              final targetId = block.referencedObjectId;
              if (targetId != null) _openObject(targetId);
            },
            blockActionsBuilder: canEditBody
                ? (context, block, position) => ObjectBodyBlockActionBar(
                      block: block,
                      position: position,
                      onMoveUp: () => _moveBodyBlockUp(block),
                      onMoveDown: () => _moveBodyBlockDown(block),
                      onDuplicate: () => _duplicateBodyBlock(block),
                      onDelete: () => _deleteBodyBlock(block),
                      onInsertAfter: (kind) => _insertBodyBlock(
                        kind,
                        afterBlockId: block.id,
                      ),
                      onInsertReferenceAfter: (kind) {
                        if (kind == ObjectBodyReferenceInsertKind.object) {
                          _insertObjectReference(
                            content,
                            afterBlockId: block.id,
                          );
                        }
                      },
                      referenceInsertKinds: const [
                        ObjectBodyReferenceInsertKind.object,
                      ],
                    )
                : null,
            emptyBuilder: (context) => !canEditBody
                ? Text(
                    'Bodyは空です',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  )
                : Row(
                    children: [
                      Text(
                        'Bodyは空です',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(width: 8),
                      ObjectBodyInsertMenuButton(
                        key: const ValueKey('body-empty-insert'),
                        onSelected: _insertBodyBlock,
                      ),
                      const SizedBox(width: 4),
                      ObjectBodyReferenceInsertMenuButton(
                        key: const ValueKey('body-empty-reference-insert'),
                        allowedKinds: const [
                          ObjectBodyReferenceInsertKind.object,
                        ],
                        onSelected: (kind) {
                          if (kind == ObjectBodyReferenceInsertKind.object) {
                            _insertObjectReference(content);
                          }
                        },
                      ),
                    ],
                  ),
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
