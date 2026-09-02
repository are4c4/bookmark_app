import '../domain/object_body.dart';
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

  Future<ObjectBodyDocument> update({
    required int objectId,
    required ObjectBodyBlock block,
  }) => _mutate(
        objectId,
        (document) => editor.updateBlock(document: document, block: block),
      );

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

  Future<ObjectBodyDocument> _mutate(
    int objectId,
    ObjectBodyDocument Function(ObjectBodyDocument document) mutation,
  ) async {
    final current = await bodyStore.read(objectId);
    final next = mutation(current);
    await bodyStore.write(objectId: objectId, document: next);
    return next;
  }
}
