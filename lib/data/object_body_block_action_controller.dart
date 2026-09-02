import '../domain/object_body.dart';
import '../domain/object_body_block_actions.dart';
import 'object_body_block_edit_service.dart';

/// Narrow adapter from shared Body action chrome to persisted block edits.
///
/// Hosts provide stable block ids for newly-created blocks. Reference-bearing
/// blocks remain outside this controller because they require target selection.
class ObjectBodyBlockActionController {
  const ObjectBodyBlockActionController({
    required this.editService,
    this.insertFactory = const ObjectBodyInsertBlockFactory(),
  });

  final ObjectBodyBlockEditService editService;
  final ObjectBodyInsertBlockFactory insertFactory;

  Future<ObjectBodyDocument> insertAfter({
    required int objectId,
    required String anchorBlockId,
    required String newBlockId,
    required ObjectBodyInsertKind kind,
    String text = '',
  }) {
    final block = insertFactory.build(
      kind: kind,
      id: newBlockId,
      text: text,
    );
    return editService.insertAfter(
      objectId: objectId,
      anchorBlockId: anchorBlockId,
      block: block,
    );
  }

  Future<ObjectBodyDocument> remove({
    required int objectId,
    required String blockId,
  }) => editService.remove(objectId: objectId, blockId: blockId);

  Future<ObjectBodyDocument> moveUp({
    required int objectId,
    required String blockId,
  }) => editService.moveUp(objectId: objectId, blockId: blockId);

  Future<ObjectBodyDocument> moveDown({
    required int objectId,
    required String blockId,
  }) => editService.moveDown(objectId: objectId, blockId: blockId);
}
