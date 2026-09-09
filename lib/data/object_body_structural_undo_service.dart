import '../domain/object_body.dart';
import '../domain/object_body_editor.dart';
import 'object_body_store.dart';

/// Short-lived inverse data for one persisted Body block deletion.
///
/// This token is deliberately in-memory only. Durable/restart-safe history is a
/// separate product contract and must not be approximated by persisting local
/// undo tokens.
class ObjectBodyDeleteUndoToken {
  const ObjectBodyDeleteUndoToken({
    required this.objectId,
    required this.deletedBlock,
    required this.deletedIndex,
    required this.afterDelete,
  });

  final int objectId;
  final ObjectBodyBlock deletedBlock;
  final int deletedIndex;
  final ObjectBodyDocument afterDelete;
}

class ObjectBodyDeleteResult {
  const ObjectBodyDeleteResult({required this.document, required this.undoToken});

  final ObjectBodyDocument document;
  final ObjectBodyDeleteUndoToken undoToken;
}

/// Provides local, lossless structural Undo without introducing durable history.
///
/// Both deletion and restoration use compare-and-swap persistence. If the Body
/// changes after the snapshot was read, the operation fails closed instead of
/// overwriting newer content.
class ObjectBodyStructuralUndoService {
  const ObjectBodyStructuralUndoService({
    required this.bodyStore,
    this.editor = const ObjectBodyEditor(),
  });

  final ObjectBodyStore bodyStore;
  final ObjectBodyEditor editor;

  Future<ObjectBodyDeleteResult> deleteWithUndo({
    required int objectId,
    required String blockId,
  }) async {
    final current = await bodyStore.read(objectId);
    final normalized = blockId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(blockId, 'blockId', 'Block id is empty.');
    }
    final index = current.blocks.indexWhere((block) => block.id == normalized);
    if (index < 0) {
      throw StateError('Body block not found: $normalized');
    }

    final deletedBlock = current.blocks[index];
    final afterDelete = editor.removeBlock(
      document: current,
      blockId: normalized,
    );
    final deleted = await bodyStore.writeIfUnchanged(
      objectId: objectId,
      expected: current,
      document: afterDelete,
    );
    if (!deleted) {
      throw const ObjectBodyUndoConflict(
        'Body changed before the block deletion could be committed.',
      );
    }

    return ObjectBodyDeleteResult(
      document: afterDelete,
      undoToken: ObjectBodyDeleteUndoToken(
        objectId: objectId,
        deletedBlock: deletedBlock,
        deletedIndex: index,
        afterDelete: afterDelete,
      ),
    );
  }

  Future<ObjectBodyDocument> undoDelete(ObjectBodyDeleteUndoToken token) async {
    final restored = editor.insertBlock(
      document: token.afterDelete,
      block: token.deletedBlock,
      index: token.deletedIndex,
    );
    final restoredSafely = await bodyStore.writeIfUnchanged(
      objectId: token.objectId,
      expected: token.afterDelete,
      document: restored,
    );
    if (!restoredSafely) {
      throw const ObjectBodyUndoConflict(
        'Body changed after deletion; Undo would overwrite newer content.',
      );
    }
    return restored;
  }
}

class ObjectBodyUndoConflict implements Exception {
  const ObjectBodyUndoConflict(this.message);

  final String message;

  @override
  String toString() => 'ObjectBodyUndoConflict: $message';
}
