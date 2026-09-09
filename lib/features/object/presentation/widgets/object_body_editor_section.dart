import 'package:flutter/material.dart';

import '../../../../data/database_view_store.dart';
import '../../../../data/generic_database_store.dart';
import '../../../../data/object_alias_store.dart';
import '../../../../data/object_body_block_action_controller.dart';
import '../../../../data/object_body_block_duplicate_service.dart';
import '../../../../data/object_body_block_edit_service.dart';
import '../../../../data/object_body_reference_insert_controller.dart';
import '../../../../data/object_body_store.dart';
import '../../../../data/object_body_structural_undo_service.dart';
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
  State<ObjectBodyEditorSection> createState() =>
      _ObjectBodyEditorSectionState();
}

class _ObjectBodyEditorSectionState extends State<ObjectBodyEditorSection> {
  static const _bodyBlockIds = ObjectBodyBlockIdAllocator();

  ObjectBodyDocument _document = const ObjectBodyDocument(
    blocks: <ObjectBodyBlock>[],
  );
  bool _loading = true;
  bool _loadFailed = false;
  int _loadGeneration = 0;
  String? _autofocusBlockId;
  int? _autofocusOffset;
  Future<void> _textMutationQueue = Future<void>.value();

  ObjectBodyStore get _bodyStore => ObjectBodyStore(widget.store);

  ObjectBodyBlockEditService get _bodyBlockEdits =>
      ObjectBodyBlockEditService(bodyStore: _bodyStore);

  ObjectBodyBlockActionController get _bodyActions =>
      ObjectBodyBlockActionController(editService: _bodyBlockEdits);

  ObjectBodyBlockDuplicateService get _bodyDuplicates =>
      ObjectBodyBlockDuplicateService(editService: _bodyBlockEdits);

  ObjectBodyStructuralUndoService get _bodyUndo =>
      ObjectBodyStructuralUndoService(bodyStore: _bodyStore);

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
        _autofocusBlockId = null;
        _autofocusOffset = null;
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
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _applyDocument(ObjectBodyDocument document) {
    if (mounted) setState(() => _document = document);
  }

  Future<void> _runMutation(
    Future<ObjectBodyDocument> Function() mutation, {
    int? expectedObjectId,
  }) async {
    final objectId = expectedObjectId ?? widget.objectId;
    try {
      final document = await mutation();
      if (!mounted || widget.objectId != objectId) return;
      _applyDocument(document);
    } catch (_) {
      if (mounted && widget.objectId == objectId) {
        _showError('Bodyを更新できませんでした。');
      }
    }
  }

  Future<void> _enqueueTextMutation(
    int objectId,
    Future<ObjectBodyDocument> Function() mutation,
  ) {
    final operation = _textMutationQueue.then((_) async {
      if (!mounted || widget.objectId != objectId) return;
      await _runMutation(mutation, expectedObjectId: objectId);
    });
    _textMutationQueue = operation;
    return operation;
  }

  Future<void> _editText(ObjectBodyBlock block, String text) {
    final objectId = widget.objectId;
    final edits = _bodyBlockEdits;
    return _enqueueTextMutation(
      objectId,
      () => edits.updateText(objectId: objectId, blockId: block.id, text: text),
    );
  }

  Future<void> _splitParagraph(
    ObjectBodyBlock block,
    TextSelection selection,
  ) async {
    final objectId = widget.objectId;
    final bodyStore = _bodyStore;
    final edits = _bodyBlockEdits;
    String? newBlockId;
    await _enqueueTextMutation(objectId, () async {
      final latest = await bodyStore.read(objectId);
      newBlockId = _bodyBlockIds.next(latest, prefix: 'paragraph');
      return edits.splitParagraph(
        objectId: objectId,
        blockId: block.id,
        newBlockId: newBlockId!,
        selectionStart: selection.start,
        selectionEnd: selection.end,
      );
    });
    if (!mounted || widget.objectId != objectId || newBlockId == null) return;
    if (_document.blocks.any((item) => item.id == newBlockId)) {
      setState(() {
        _autofocusBlockId = newBlockId;
        _autofocusOffset = 0;
      });
    }
  }

  Future<void> _mergeParagraphIntoPrevious(ObjectBodyBlock block) async {
    final objectId = widget.objectId;
    final bodyStore = _bodyStore;
    final edits = _bodyBlockEdits;
    String? targetBlockId;
    int? targetOffset;

    await _enqueueTextMutation(objectId, () async {
      final latest = await bodyStore.read(objectId);
      final index = latest.blocks.indexWhere((item) => item.id == block.id);
      if (index <= 0) return latest;
      final previous = latest.blocks[index - 1];
      targetBlockId = previous.id;
      targetOffset = (previous.text ?? '').length;
      return edits.mergeParagraphIntoPrevious(
        objectId: objectId,
        blockId: block.id,
      );
    });

    if (!mounted || widget.objectId != objectId || targetBlockId == null) {
      return;
    }
    final merged =
        !_document.blocks.any((item) => item.id == block.id) &&
        _document.blocks.any((item) => item.id == targetBlockId);
    if (!merged) return;
    setState(() {
      _autofocusBlockId = targetBlockId;
      _autofocusOffset = targetOffset;
    });
  }

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
    () => _bodyActions.moveUp(objectId: widget.objectId, blockId: block.id),
  );

  Future<void> _moveDown(ObjectBodyBlock block) => _runMutation(
    () => _bodyActions.moveDown(objectId: widget.objectId, blockId: block.id),
  );

  Future<void> _reorder(ObjectBodyBlock block, int toIndex) => _runMutation(
    () => _bodyBlockEdits.move(
      objectId: widget.objectId,
      blockId: block.id,
      toIndex: toIndex,
    ),
  );

  Future<void> _delete(ObjectBodyBlock block) async {
    final objectId = widget.objectId;
    final undoService = _bodyUndo;
    try {
      final result = await undoService.deleteWithUndo(
        objectId: objectId,
        blockId: block.id,
      );
      if (!mounted || widget.objectId != objectId) return;
      _applyDocument(result.document);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text('ブロックを削除しました'),
          action: SnackBarAction(
            label: '元に戻す',
            onPressed: () => _undoDelete(undoService, result.undoToken),
          ),
        ),
      );
    } catch (_) {
      if (mounted && widget.objectId == objectId) {
        _showError('Bodyを更新できませんでした。');
      }
    }
  }

  Future<void> _undoDelete(
    ObjectBodyStructuralUndoService undoService,
    ObjectBodyDeleteUndoToken token,
  ) async {
    try {
      final document = await undoService.undoDelete(token);
      if (!mounted || widget.objectId != token.objectId) return;
      _applyDocument(document);
    } on ObjectBodyUndoConflict {
      if (mounted && widget.objectId == token.objectId) {
        _showError('新しい変更があるため元に戻せませんでした。');
      }
    } catch (_) {
      if (mounted && widget.objectId == token.objectId) {
        _showError('Bodyを元に戻せませんでした。');
      }
    }
  }

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
                const Expanded(child: Text('Bodyを読み込めませんでした。内容は変更されていません。')),
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
          onParagraphSplit: _splitParagraph,
          onParagraphMergeWithPrevious: _mergeParagraphIntoPrevious,
          autofocusBlockId: _autofocusBlockId,
          autofocusOffset: _autofocusOffset,
          onChecklistChanged: (block, checked) =>
              _toggleChecklist(block, checked),
          onObjectReferenceTap: (block) {
            final targetId = block.referencedObjectId;
            if (targetId != null) widget.onOpenObject?.call(targetId);
          },
          onBlockReorder: _reorder,
          blockActionsBuilder: (context, block, position) =>
              ObjectBodyBlockActionBar(
                block: block,
                position: position,
                onMoveUp: () => _moveUp(block),
                onMoveDown: () => _moveDown(block),
                onDuplicate: () => _duplicate(block),
                onDelete: () => _delete(block),
                onInsertAfter: (kind) =>
                    _insertBlock(kind, afterBlockId: block.id),
                onInsertReferenceAfter: (kind) =>
                    _insertReference(kind, afterBlockId: block.id),
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
