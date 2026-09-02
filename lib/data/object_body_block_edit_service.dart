import '../domain/object_body.dart';
import '../domain/object_body_block_contracts.dart';
import '../domain/object_body_editor.dart';
import 'object_body_store.dart';

/// Persistence boundary for block-level Object Body editing.
///
/// Each operation reads the latest stored document before applying a narrow
/// immutable change. This avoids routing richer documents through the legacy
/// paragraph/plain-text adapter and preserves unrelated/unknown block payloads.
class ObjectBodyBlockEditService {
  const ObjectBodyBlockEditService({
    required this.bodyStore,
    this.editor = const ObjectBodyEditor(),
  });

  final ObjectBodyStore bodyStore;
  final ObjectBodyEditor editor;

  Future<ObjectBodyDocument> insert({
    required int objectId,
    required ObjectBodyBlock block,
    int? index,
  }) => _mutate(
        objectId,
        (document) => editor.insertBlock(
          document: document,
          block: block,
          index: index,
        ),
      );

  /// Inserts [block] immediately after [anchorBlockId] in the latest Body.
  ///
  /// Resolving the anchor and mutating happen against the same latest read, so
  /// hosts do not need to compute a potentially stale numeric insertion index.
  Future<ObjectBodyDocument> insertAfter({
    required int objectId,
    required String anchorBlockId,
    required ObjectBodyBlock block,
  }) => _mutate(objectId, (document) {
        final anchor = anchorBlockId.trim();
        if (anchor.isEmpty) {
          throw ArgumentError.value(
            anchorBlockId,
            'anchorBlockId',
            'Block id is empty.',
          );
        }
        final index = document.blocks.indexWhere((item) => item.id == anchor);
        if (index < 0) {
          throw StateError('Body block not found: $anchor');
        }
        return editor.insertBlock(
          document: document,
          block: block,
          index: index + 1,
        );
      });

  Future<ObjectBodyDocument> update({
    required int objectId,
    required ObjectBodyBlock block,
  }) => _mutate(
        objectId,
        (document) => editor.updateBlock(document: document, block: block),
      );

  /// Updates only the text payload of a known text-editable block.
  ///
  /// The latest persisted block is re-read first, so unrelated attributes and
  /// future metadata survive edits made by a shared Flutter text control.
  Future<ObjectBodyDocument> updateText({
    required int objectId,
    required String blockId,
    required String text,
  }) => _mutate(objectId, (document) {
        final block = _blockById(document, blockId);
        if (!_textEditableTypes.contains(block.type)) {
          throw StateError('Body block $blockId is not text-editable.');
        }
        return editor.updateBlock(
          document: document,
          block: block.copyWith(text: text),
        );
      });

  /// Updates checklist state without replacing its text or other attributes.
  Future<ObjectBodyDocument> setChecklistChecked({
    required int objectId,
    required String blockId,
    required bool checked,
  }) => _mutate(objectId, (document) {
        final block = _blockById(document, blockId);
        if (block.type != ObjectBodyBlockType.checklist) {
          throw StateError('Body block $blockId is not a checklist.');
        }
        return editor.updateBlock(
          document: document,
          block: block.copyWith(
            attributes: <String, dynamic>{
              ...block.attributes,
              ObjectBodyBlockAttribute.checked: checked,
            },
          ),
        );
      });

  Future<ObjectBodyDocument> remove({
    required int objectId,
    required String blockId,
  }) => _mutate(
        objectId,
        (document) => editor.removeBlock(document: document, blockId: blockId),
      );

  Future<ObjectBodyDocument> move({
    required int objectId,
    required String blockId,
    required int toIndex,
  }) => _mutate(
        objectId,
        (document) => editor.moveBlock(
          document: document,
          blockId: blockId,
          toIndex: toIndex,
        ),
      );

  /// Moves a block one position upward using the latest persisted ordering.
  /// Already-first blocks are left unchanged rather than failing.
  Future<ObjectBodyDocument> moveUp({
    required int objectId,
    required String blockId,
  }) => _moveByOffset(objectId: objectId, blockId: blockId, offset: -1);

  /// Moves a block one position downward using the latest persisted ordering.
  /// Already-last blocks are left unchanged rather than failing.
  Future<ObjectBodyDocument> moveDown({
    required int objectId,
    required String blockId,
  }) => _moveByOffset(objectId: objectId, blockId: blockId, offset: 1);

  Future<ObjectBodyDocument> _moveByOffset({
    required int objectId,
    required String blockId,
    required int offset,
  }) => _mutate(objectId, (document) {
        final normalized = blockId.trim();
        if (normalized.isEmpty) {
          throw ArgumentError.value(blockId, 'blockId', 'Block id is empty.');
        }
        final index = document.blocks.indexWhere((block) => block.id == normalized);
        if (index < 0) {
          throw StateError('Body block not found: $normalized');
        }
        final target = index + offset;
        if (target < 0 || target >= document.blocks.length) return document;
        return editor.moveBlock(
          document: document,
          blockId: normalized,
          toIndex: target,
        );
      });

  Future<ObjectBodyDocument> _mutate(
    int objectId,
    ObjectBodyDocument Function(ObjectBodyDocument document) mutation,
  ) async {
    final current = await bodyStore.read(objectId);
    final next = mutation(current);
    await bodyStore.write(objectId: objectId, document: next);
    return next;
  }

  ObjectBodyBlock _blockById(ObjectBodyDocument document, String blockId) {
    for (final block in document.blocks) {
      if (block.id == blockId) return block;
    }
    throw StateError('Body block not found: $blockId');
  }

  static const _textEditableTypes = <String>{
    ObjectBodyBlockType.paragraph,
    ObjectBodyBlockType.heading,
    ObjectBodyBlockType.bulletedListItem,
    ObjectBodyBlockType.numberedListItem,
    ObjectBodyBlockType.checklist,
    ObjectBodyBlockType.quote,
    ObjectBodyBlockType.callout,
    ObjectBodyBlockType.code,
  };
}
