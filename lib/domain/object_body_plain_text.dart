import 'object_body.dart';

/// Thin compatibility adapter for an initial simple Body editor.
///
/// It deliberately refuses to edit documents containing non-paragraph blocks
/// so a basic text field can never silently discard richer/future content.
class ObjectBodyPlainTextAdapter {
  const ObjectBodyPlainTextAdapter();

  bool canEdit(ObjectBodyDocument document) =>
      document.blocks.every((block) => block.type == 'paragraph');

  String read(ObjectBodyDocument document) {
    _assertEditable(document);
    return document.blocks.map((block) => block.text ?? '').join('\n\n');
  }

  ObjectBodyDocument write({
    required ObjectBodyDocument document,
    required String text,
    required String Function(int index) blockIdForIndex,
  }) {
    _assertEditable(document);
    if (text.isEmpty) {
      return document.copyWith(blocks: const <ObjectBodyBlock>[]);
    }

    final parts = text.split('\n\n');
    final blocks = <ObjectBodyBlock>[];
    for (var index = 0; index < parts.length; index++) {
      final existingId = index < document.blocks.length
          ? document.blocks[index].id
          : null;
      final id = existingId ?? blockIdForIndex(index).trim();
      if (id.isEmpty) {
        throw ArgumentError.value(
          id,
          'blockIdForIndex',
          'Generated block id cannot be empty.',
        );
      }
      blocks.add(ObjectBodyBlock.paragraph(id: id, text: parts[index]));
    }
    return document.copyWith(blocks: List<ObjectBodyBlock>.unmodifiable(blocks));
  }

  void _assertEditable(ObjectBodyDocument document) {
    if (!canEdit(document)) {
      throw StateError(
        'Plain-text editing is disabled because the Body contains non-paragraph blocks.',
      );
    }
  }
}
