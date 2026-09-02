import 'object_body.dart';
import 'object_body_block_contracts.dart';

enum ObjectBodyInsertKind {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletedListItem,
  numberedListItem,
  checklist,
  quote,
  callout,
  code,
  divider,
}

/// Builds only currently-supported, non-reference blocks for generic Body UI.
///
/// Reference-bearing Object/Database/asset blocks keep their dedicated flows,
/// where the target identity must be chosen explicitly before insertion.
class ObjectBodyInsertBlockFactory {
  const ObjectBodyInsertBlockFactory({
    this.blockFactory = const ObjectBodyBlockFactory(),
  });

  final ObjectBodyBlockFactory blockFactory;

  ObjectBodyBlock build({
    required ObjectBodyInsertKind kind,
    required String id,
    String text = '',
  }) {
    switch (kind) {
      case ObjectBodyInsertKind.paragraph:
        return blockFactory.paragraph(id: id, text: text);
      case ObjectBodyInsertKind.heading1:
        return blockFactory.heading(id: id, level: 1, text: text);
      case ObjectBodyInsertKind.heading2:
        return blockFactory.heading(id: id, level: 2, text: text);
      case ObjectBodyInsertKind.heading3:
        return blockFactory.heading(id: id, level: 3, text: text);
      case ObjectBodyInsertKind.bulletedListItem:
        return ObjectBodyBlock(
          id: id,
          type: ObjectBodyBlockType.bulletedListItem,
          text: text,
        );
      case ObjectBodyInsertKind.numberedListItem:
        return ObjectBodyBlock(
          id: id,
          type: ObjectBodyBlockType.numberedListItem,
          text: text,
        );
      case ObjectBodyInsertKind.checklist:
        return blockFactory.checklist(id: id, text: text);
      case ObjectBodyInsertKind.quote:
        return ObjectBodyBlock(
          id: id,
          type: ObjectBodyBlockType.quote,
          text: text,
        );
      case ObjectBodyInsertKind.callout:
        return ObjectBodyBlock(
          id: id,
          type: ObjectBodyBlockType.callout,
          text: text,
        );
      case ObjectBodyInsertKind.code:
        return blockFactory.code(id: id, text: text);
      case ObjectBodyInsertKind.divider:
        return blockFactory.divider(id: id);
    }
  }
}

class ObjectBodyBlockPosition {
  const ObjectBodyBlockPosition({
    required this.index,
    required this.count,
  });

  final int index;
  final int count;

  bool get canMoveUp => index > 0;
  bool get canMoveDown => index >= 0 && index < count - 1;
}

class ObjectBodyBlockPositionResolver {
  const ObjectBodyBlockPositionResolver();

  ObjectBodyBlockPosition resolve(
    ObjectBodyDocument document,
    String blockId,
  ) {
    final normalized = blockId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(blockId, 'blockId', 'Block id is empty.');
    }
    final index = document.blocks.indexWhere((block) => block.id == normalized);
    if (index < 0) {
      throw StateError('Object Body block $normalized does not exist.');
    }
    return ObjectBodyBlockPosition(index: index, count: document.blocks.length);
  }
}
