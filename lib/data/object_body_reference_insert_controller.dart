import '../domain/object_body.dart';
import '../domain/object_body_reference_insert.dart';
import 'object_body_block_edit_service.dart';

/// Persists fully-selected Object/Database/asset reference blocks through the
/// same latest-read Body mutation path as generic block actions.
///
/// Target selection/validation belongs to the caller's feature-specific flow;
/// this controller only accepts an explicit reference request and a fresh block
/// identity. It never creates placeholder or unresolved reference blocks.
class ObjectBodyReferenceInsertController {
  const ObjectBodyReferenceInsertController({required this.editService});

  final ObjectBodyBlockEditService editService;

  Future<ObjectBodyDocument> insert({
    required int objectId,
    required String blockId,
    required ObjectBodyReferenceInsertRequest request,
  }) {
    final block = request.toBlock(blockId: blockId);
    return editService.insert(objectId: objectId, block: block);
  }

  Future<ObjectBodyDocument> insertAfter({
    required int objectId,
    required String anchorBlockId,
    required String blockId,
    required ObjectBodyReferenceInsertRequest request,
  }) {
    final block = request.toBlock(blockId: blockId);
    return editService.insertAfter(
      objectId: objectId,
      anchorBlockId: anchorBlockId,
      block: block,
    );
  }
}
