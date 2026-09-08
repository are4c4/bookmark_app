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

  /// Splits one paragraph across the current text selection and inserts a new
  /// paragraph immediately after it without rewriting unrelated block payload.
  ///
  /// A collapsed selection behaves like a cursor split. A non-collapsed
  /// selection is replaced by the paragraph break, matching ordinary document
  /// editor behavior.
  ObjectBodyDocument splitParagraph({
    required ObjectBodyDocument document,
    required String blockId,
    required String newBlockId,
    required int selectionStart,
    required int selectionEnd,
  }) {
    _assertUniqueId(document, newBlockId);
    final index = _indexOf(document, blockId);
    final block = document.blocks[index];
    if (block.type != 'paragraph') {
      throw StateError('Object Body block $blockId is not a paragraph.');
    }
    final text = block.text ?? '';
    if (selectionStart < 0 || selectionStart > text.length) {
      throw RangeError.range(
        selectionStart,
        0,
        text.length,
        'selectionStart',
      );
    }
    if (selectionEnd < selectionStart || selectionEnd > text.length) {
      throw RangeError.range(
        selectionEnd,
        selectionStart,
        text.length,
        'selectionEnd',
      );
    }

    final next = List<ObjectBodyBlock>.of(document.blocks);
    next[index] = block.copyWith(text: text.substring(0, selectionStart));
    next.insert(
      index + 1,
      ObjectBodyBlock.paragraph(
        id: newBlockId,
        text: text.substring(selectionEnd),
      ),
    );
    return document.copyWith(blocks: List.unmodifiable(next));
  }

  /// Merges a plain paragraph into the previous plain paragraph.
  ///
  /// This is intentionally conservative: styled/attributed paragraphs or a
  /// non-paragraph predecessor are left untouched so Backspace never discards
  /// block-level semantics merely to mimic a text editor.
  ObjectBodyDocument mergeParagraphIntoPrevious({
    required ObjectBodyDocument document,
    required String blockId,
  }) {
    final index = _indexOf(document, blockId);
    if (index == 0) return document;

    final current = document.blocks[index];
    final previous = document.blocks[index - 1];
    if (current.type != 'paragraph' ||
        previous.type != 'paragraph' ||
        current.attributes.isNotEmpty ||
        previous.attributes.isNotEmpty) {
      return document;
    }

    final next = List<ObjectBodyBlock>.of(document.blocks);
    next[index - 1] = previous.copyWith(
      text: '${previous.text ?? ''}${current.text ?? ''}',
    );
    next.removeAt(index);
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
