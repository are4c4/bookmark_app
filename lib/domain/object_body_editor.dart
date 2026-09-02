import 'object_body.dart';

/// Pure, immutable editing operations for an Object Body document.
///
/// The editor intentionally preserves unknown block types and attributes. It
/// only changes the block explicitly targeted by the caller so richer/future
/// documents are not flattened by simple editing flows.
class ObjectBodyEditor {
  const ObjectBodyEditor();

  ObjectBodyDocument insertBlock({
    required ObjectBodyDocument document,
    required ObjectBodyBlock block,
    int? index,
  }) {
    _assertUniqueId(document, block.id);
    final next = List<ObjectBodyBlock>.of(document.blocks);
    final insertionIndex = index ?? next.length;
    if (insertionIndex < 0 || insertionIndex > next.length) {
      throw RangeError.range(insertionIndex, 0, next.length, 'index');
    }
    next.insert(insertionIndex, block);
    return document.copyWith(blocks: List.unmodifiable(next));
  }

  ObjectBodyDocument updateBlock({
    required ObjectBodyDocument document,
    required ObjectBodyBlock block,
  }) {
    final index = _indexOf(document, block.id);
    final next = List<ObjectBodyBlock>.of(document.blocks);
    next[index] = block;
    return document.copyWith(blocks: List.unmodifiable(next));
  }

  ObjectBodyDocument removeBlock({
    required ObjectBodyDocument document,
    required String blockId,
  }) {
    final index = _indexOf(document, blockId);
    final next = List<ObjectBodyBlock>.of(document.blocks)..removeAt(index);
    return document.copyWith(blocks: List.unmodifiable(next));
  }

  ObjectBodyDocument moveBlock({
    required ObjectBodyDocument document,
    required String blockId,
    required int toIndex,
  }) {
    final fromIndex = _indexOf(document, blockId);
    final next = List<ObjectBodyBlock>.of(document.blocks);
    if (toIndex < 0 || toIndex >= next.length) {
      throw RangeError.range(toIndex, 0, next.length - 1, 'toIndex');
    }
    final block = next.removeAt(fromIndex);
    next.insert(toIndex, block);
    return document.copyWith(blocks: List.unmodifiable(next));
  }

  int _indexOf(ObjectBodyDocument document, String blockId) {
    final normalized = blockId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(blockId, 'blockId', 'Block id is empty.');
    }
    for (var index = 0; index < document.blocks.length; index++) {
      if (document.blocks[index].id == normalized) return index;
    }
    throw StateError('Object Body block $normalized does not exist.');
  }

  void _assertUniqueId(ObjectBodyDocument document, String blockId) {
    final normalized = blockId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(blockId, 'block.id', 'Block id is empty.');
    }
    if (document.blocks.any((block) => block.id == normalized)) {
      throw StateError('Object Body block id $normalized already exists.');
    }
  }
}
