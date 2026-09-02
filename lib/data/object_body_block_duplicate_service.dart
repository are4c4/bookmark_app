import '../domain/object_body.dart';
import '../domain/object_body_block_identity.dart';
import 'object_body_block_edit_service.dart';

class ObjectBodyBlockDuplicateResult {
  const ObjectBodyBlockDuplicateResult({
    required this.blockId,
    required this.document,
  });

  final String blockId;
  final ObjectBodyDocument document;
}

/// Duplicates one persisted Body block immediately after its source while
/// preserving the source payload, including unknown/future attributes.
///
/// Identity allocation is based on the latest persisted document. The final
/// insert goes through [ObjectBodyBlockEditService], which re-reads before the
/// mutation and therefore fails closed if a concurrent edit reused the id or
/// removed the source in between.
class ObjectBodyBlockDuplicateService {
  const ObjectBodyBlockDuplicateService({
    required this.editService,
    this.idAllocator = const ObjectBodyBlockIdAllocator(),
    this.duplicator = const ObjectBodyBlockDuplicator(),
  });

  final ObjectBodyBlockEditService editService;
  final ObjectBodyBlockIdAllocator idAllocator;
  final ObjectBodyBlockDuplicator duplicator;

  Future<ObjectBodyBlockDuplicateResult> duplicateAfter({
    required int objectId,
    required String sourceBlockId,
  }) async {
    final normalized = sourceBlockId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        sourceBlockId,
        'sourceBlockId',
        'Block id is empty.',
      );
    }

    final current = await editService.bodyStore.read(objectId);
    ObjectBodyBlock? source;
    for (final block in current.blocks) {
      if (block.id == normalized) {
        source = block;
        break;
      }
    }
    if (source == null) {
      throw StateError('Body block not found: $normalized');
    }

    final newId = idAllocator.next(current, prefix: _prefixFor(source));
    final duplicate = duplicator.duplicate(source: source, newId: newId);
    final document = await editService.insertAfter(
      objectId: objectId,
      anchorBlockId: normalized,
      block: duplicate,
    );
    return ObjectBodyBlockDuplicateResult(blockId: newId, document: document);
  }

  String _prefixFor(ObjectBodyBlock source) {
    final normalizedType = source.type.trim().toLowerCase();
    return normalizedType.isEmpty ? 'block-copy' : '$normalizedType-copy';
  }
}
