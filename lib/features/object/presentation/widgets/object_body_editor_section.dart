import 'package:flutter/material.dart';

import '../../../../data/database_view_store.dart';
import '../../../../data/generic_database_store.dart';
import '../../../../data/object_alias_store.dart';
import '../../../../data/object_body_block_action_controller.dart';
import '../../../../data/object_body_block_duplicate_service.dart';
import '../../../../data/object_body_block_edit_service.dart';
import '../../../../data/object_body_reference_insert_controller.dart';
import '../../../../data/object_body_store.dart';
import '../../../../data/object_identity_search_service.dart';
import '../../../../data/object_store.dart';
import '../../../../domain/object_body.dart';
import '../../../../domain/object_body_block_actions.dart';
import '../../../../domain/object_body_block_contracts.dart';
import '../../../../domain/object_body_block_identity.dart';
import '../../../../domain/object_body_reference_insert.dart';
import '../object_body_database_view_reference_catalog.dart';
import '../object_body_object_reference_catalog.dart';
import 'object_body_block_action_bar.dart';
import 'object_body_database_view_reference_picker.dart';
import 'object_body_document_view.dart';
import 'object_body_insert_menu_button.dart';
import 'object_body_object_reference_picker.dart';
import 'object_body_reference_insert_menu_button.dart';

/// Reusable rich Body editor for any persisted Object.
///
/// This widget owns only the universal Body editing contract. ObjectType-specific
/// identity, Properties, media and surrounding detail chrome remain with the host.
class ObjectBodyEditorSection extends StatefulWidget {
  const ObjectBodyEditorSection({
    super.key,
    required this.store,
    required this.objectStore,
    required this.objectId,
    required this.workspaceId,
    this.onOpenObject,
    this.showHeading = true,
  });

  final GenericDatabaseStore store;
  final ObjectStore objectStore;
  final int objectId;
  final int workspaceId;
  final ValueChanged<int>? onOpenObject;
  final bool showHeading;

  @override
  State<ObjectBodyEditorSection> createState() => _ObjectBodyEditorSectionState();
}

class _ObjectBodyEditorSectionState extends State<ObjectBodyEditorSection> {
  static const _bodyBlockIds = ObjectBodyBlockIdAllocator();

  ObjectBodyDocument _document = const ObjectBodyDocument(
    blocks: <ObjectBodyBlock>[],
  );
  bool _loading = true;
  bool _loadFailed = false;
  int _loadGeneration = 0;

  ObjectBodyStore get _bodyStore => ObjectBodyStore(widget.store);

  ObjectBodyBlockEditService get _bodyBlockEdits =>
      ObjectBodyBlockEditService(bodyStore: _bodyStore);

  ObjectBodyBlockActionController get _bodyActions =>
      ObjectBodyBlockActionController(editService: _bodyBlockEdits);

  ObjectBodyBlockDuplicateService get _bodyDuplicates =>
      ObjectBodyBlockDuplicateService(editService: _bodyBlockEdits);

  ObjectBodyReferenceInsertController get _bodyReferenceInserts =>
      ObjectBodyReferenceInsertController(editService: _bodyBlockEdits);

  ObjectBodyObjectReferenceCatalog get _objectReferenceCatalog =>
      ObjectBodyObjectReferenceCatalog(
        identitySearch: ObjectIdentitySearchService(
          objectStore: widget.objectStore,
          aliasStore: ObjectAliasStore(widget.store),
        ),
      );

  ObjectBodyDatabaseViewReferenceCatalog get _databaseViewReferenceCatalog =>
      ObjectBodyDatabaseViewReferenceCatalog(
        databaseStore: widget.store,
        viewStore: DatabaseViewStore(widget.store.database),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ObjectBodyEditorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.objectId != widget.objectId ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.store != widget.store ||
        oldWidget.objectStore != widget.objectStore) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final objectId = widget.objectId;
    final bodyStore = ObjectBodyStore(widget.store);
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final document = await bodyStore.read(objectId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _document = document;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _applyDocument(ObjectBodyDocument document) {
    if (mounted) setState(() => _document = document);
  }

  Future<void> _runMutation(
    Future<ObjectBodyDocument> Function() mutation,
  ) async {
    try {
      _applyDocument(await mutation());
    } catch (_) {
      _showError('Bodyを更新できませんでした。');
    }
  }

  Future<void> _editText(ObjectBodyBlock block, String text) => _runMutation(
        () => _bodyBlockEdits.updateText(
          objectId: widget.objectId,
          blockId: block.id,
          text: text,
        ),
      );

  Future<void> _toggleChecklist(ObjectBodyBlock block, bool checked) =>
      _runMutation(
        () => _bodyBlockEdits.setChecklistChecked(
          objectId: widget.objectId,
          blockId: block.id,
          checked: checked,
        ),
      );

  Future<void> _insertBlock(
    ObjectBodyInsertKind kind, {
    String? afterBlockId,
  }) async {
    final latest = await _bodyStore.read(widget.objectId);
    final newBlockId = _bodyBlockIds.next(latest, prefix: kind.name);
    await _runMutation(
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

  Future<void> _insertObjectReference({String? afterBlockId}) async {
    try {
      final candidates = await _objectReferenceCatalog.load(
        workspaceId: widget.workspaceId,
      );
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
      _applyDocument(result.document);
    } catch (_) {
      _showError('Object参照を追加できませんでした。');
    }
  }

  Future<void> _insertDatabaseViewReference({String? afterBlockId}) async {
    try {
      final candidates = await _databaseViewReferenceCatalog.load(
        workspaceId: widget.workspaceId,
      );
      if (!mounted) return;
      final target = await showObjectBodyDatabaseViewReferencePicker(
        context,
        candidates: candidates,
      );
      if (target == null) return;
      final request = ObjectBodyDatabaseViewInsert(
        databaseId: target.databaseId,
        viewId: target.viewId,
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
      _applyDocument(result.document);
    } catch (_) {
      _showError('Database / View参照を追加できませんでした。');
    }
  }

  Future<void> _moveUp(ObjectBodyBlock block) => _runMutation(
        () => _bodyActions.moveUp(
          objectId: widget.objectId,
          blockId: block.id,
        ),
      );

  Future<void> _moveDown(ObjectBodyBlock block) => _runMutation(
        () => _bodyActions.moveDown(
          objectId: widget.objectId,
          blockId: block.id,
        ),
      );

  Future<void> _delete(ObjectBodyBlock block) => _runMutation(
        () => _bodyActions.remove(
          objectId: widget.objectId,
          blockId: block.id,
        ),
      );

  Future<void> _duplicate(ObjectBodyBlock block) async {
    try {
      final result = await _bodyDuplicates.duplicateAfter(
        objectId: widget.objectId,
        sourceBlockId: block.id,
      );
      _applyDocument(result.document);
    } catch (_) {
      _showError('Bodyを更新できませんでした。');
    }
  }

  void _insertReference(
    ObjectBodyReferenceInsertKind kind, {
    String? afterBlockId,
  }) {
    switch (kind) {
      case ObjectBodyReferenceInsertKind.object:
        _insertObjectReference(afterBlockId: afterBlockId);
      case ObjectBodyReferenceInsertKind.databaseView:
        _insertDatabaseViewReference(afterBlockId: afterBlockId);
      case ObjectBodyReferenceInsertKind.image:
      case ObjectBodyReferenceInsertKind.file:
        break;
    }
  }

  Widget _heading(BuildContext context) =>
      Text('Body', style: Theme.of(context).textTheme.titleMedium);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    if (_loadFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeading) ...[
            _heading(context),
            const SizedBox(height: 8),
          ],
          Container(
            key: const ValueKey('body-load-error'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Bodyを読み込めませんでした。内容は変更されていません。'),
                ),
                TextButton(
                  key: const ValueKey('body-load-retry'),
                  onPressed: _load,
                  child: const Text('再試行'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeading) ...[
          _heading(context),
          const SizedBox(height: 8),
        ],
        ObjectBodyDocumentView(
          document: _document,
          onTextChanged: (block, text) => _editText(block, text),
          onChecklistChanged: (block, checked) =>
              _toggleChecklist(block, checked),
          onObjectReferenceTap: (block) {
            final targetId = block.referencedObjectId;
            if (targetId != null) widget.onOpenObject?.call(targetId);
          },
          blockActionsBuilder: (context, block, position) =>
              ObjectBodyBlockActionBar(
            block: block,
            position: position,
            onMoveUp: () => _moveUp(block),
            onMoveDown: () => _moveDown(block),
            onDuplicate: () => _duplicate(block),
            onDelete: () => _delete(block),
            onInsertAfter: (kind) => _insertBlock(
              kind,
              afterBlockId: block.id,
            ),
            onInsertReferenceAfter: (kind) => _insertReference(
              kind,
              afterBlockId: block.id,
            ),
            referenceInsertKinds: const [
              ObjectBodyReferenceInsertKind.object,
              ObjectBodyReferenceInsertKind.databaseView,
            ],
          ),
          emptyBuilder: (context) => Row(
            children: [
              Text(
                'Bodyは空です',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 8),
              ObjectBodyInsertMenuButton(
                key: const ValueKey('body-empty-insert'),
                onSelected: _insertBlock,
              ),
              const SizedBox(width: 4),
              ObjectBodyReferenceInsertMenuButton(
                key: const ValueKey('body-empty-reference-insert'),
                allowedKinds: const [
                  ObjectBodyReferenceInsertKind.object,
                  ObjectBodyReferenceInsertKind.databaseView,
                ],
                onSelected: _insertReference,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
