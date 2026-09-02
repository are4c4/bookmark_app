import '../domain/object_body.dart';
import '../domain/object_body_block_identity.dart';
import '../domain/object_body_reference_insert.dart';
import 'object_body_block_edit_service.dart';

class ObjectBodyReferenceInsertResult {
  const ObjectBodyReferenceInsertResult({
    required this.blockId,
    required this.document,
  });

  final String blockId;
  final ObjectBodyDocument document;
}

/// Persists fully-selected Object/Database/asset reference blocks through the
/// same latest-read Body mutation path as generic block actions.
///
/// Target selection/validation belongs to the caller's feature-specific flow;
/// this controller only accepts an explicit reference request. It never creates
/// placeholder or unresolved reference blocks.
class ObjectBodyReferenceInsertController {
  const ObjectBodyReferenceInsertController({
    required this.editService,
    this.idAllocator = const ObjectBodyBlockIdAllocator(),
  });

  final ObjectBodyBlockEditService editService;
  final ObjectBodyBlockIdAllocator idAllocator;

  Future<ObjectBodyDocument> insert({
    required int objectId,
    required String blockId,
    required ObjectBodyReferenceInsertRequest request,
  }) async {
    final block = request.toBlock(blockId: blockId);
    return editService.insert(objectId: objectId, block: block);
  }

  Future<ObjectBodyDocument> insertAfter({
    required int objectId,
    required String anchorBlockId,
    required String blockId,
    required ObjectBodyReferenceInsertRequest request,
  }) async {
    final block = request.toBlock(blockId: blockId);
    return editService.insertAfter(
      objectId: objectId,
      anchorBlockId: anchorBlockId,
      block: block,
    );
  }

  /// Allocates a stable id from the latest persisted document so shared hosts
  /// do not need their own block-id policy for reference insertion.
  Future<ObjectBodyReferenceInsertResult> insertAllocated({
    required int objectId,
    required ObjectBodyReferenceInsertRequest request,
  }) async {
    final current = await editService.bodyStore.read(objectId);
    final blockId = idAllocator.next(current, prefix: _prefixFor(request));
    final document = await insert(
      objectId: objectId,
      blockId: blockId,
      request: request,
    );
    return ObjectBodyReferenceInsertResult(
      blockId: blockId,
      document: document,
    );
  }

  /// Allocates an id and inserts after [anchorBlockId]. If another edit wins
  /// between allocation and persistence, the underlying editor fails closed on
  /// duplicate identity rather than rewriting either block.
  Future<ObjectBodyReferenceInsertResult> insertAfterAllocated({
    required int objectId,
    required String anchorBlockId,
    required ObjectBodyReferenceInsertRequest request,
  }) async {
    final current = await editService.bodyStore.read(objectId);
    final blockId = idAllocator.next(current, prefix: _prefixFor(request));
    final document = await insertAfter(
      objectId: objectId,
      anchorBlockId: anchorBlockId,
      blockId: blockId,
      request: request,
    );
    return ObjectBodyReferenceInsertResult(
      blockId: blockId,
      document: document,
    );
  }

  String _prefixFor(ObjectBodyReferenceInsertRequest request) => switch (request) {
        ObjectBodyObjectReferenceInsert() => 'object-ref',
        ObjectBodyDatabaseViewInsert() => 'database-view',
        ObjectBodyAssetReferenceInsert(:final kind) => switch (kind) {
            ObjectBodyAssetReferenceKind.image => 'image',
            ObjectBodyAssetReferenceKind.file => 'file',
          },
      };
}
