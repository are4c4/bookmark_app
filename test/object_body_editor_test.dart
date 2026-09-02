import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const editor = ObjectBodyEditor();

  test('insert/update/remove preserve unrelated rich blocks', () {
    const future = ObjectBodyBlock(
      id: 'future',
      type: 'embed',
      attributes: <String, dynamic>{'objectId': 42},
    );
    const initial = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'one'),
        future,
      ],
    );

    final inserted = editor.insertBlock(
      document: initial,
      block: const ObjectBodyBlock(id: 'p2', type: 'paragraph', text: 'two'),
      index: 1,
    );
    expect(inserted.blocks.map((block) => block.id), ['p1', 'p2', 'future']);
    expect(inserted.blocks.last.toJson(), future.toJson());

    final updated = editor.updateBlock(
      document: inserted,
      block: const ObjectBodyBlock(id: 'p2', type: 'paragraph', text: 'changed'),
    );
    expect(updated.blocks[1].text, 'changed');
    expect(updated.blocks.last.toJson(), future.toJson());

    final removed = editor.removeBlock(document: updated, blockId: 'p1');
    expect(removed.blocks.map((block) => block.id), ['p2', 'future']);
    expect(removed.blocks.last.toJson(), future.toJson());
  });

  test('move reorders blocks without rewriting their payload', () {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'a', type: 'paragraph', text: 'A'),
        ObjectBodyBlock(
          id: 'b',
          type: 'callout',
          text: 'B',
          attributes: <String, dynamic>{'icon': '💡'},
        ),
        ObjectBodyBlock(id: 'c', type: 'paragraph', text: 'C'),
      ],
    );

    final moved = editor.moveBlock(document: document, blockId: 'b', toIndex: 0);

    expect(moved.blocks.map((block) => block.id), ['b', 'a', 'c']);
    expect(moved.blocks.first.toJson(), document.blocks[1].toJson());
  });

  test('invalid edits fail closed', () {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'a', type: 'paragraph'),
      ],
    );

    expect(
      () => editor.insertBlock(
        document: document,
        block: const ObjectBodyBlock(id: 'a', type: 'paragraph'),
      ),
      throwsStateError,
    );
    expect(
      () => editor.updateBlock(
        document: document,
        block: const ObjectBodyBlock(id: 'missing', type: 'paragraph'),
      ),
      throwsStateError,
    );
    expect(
      () => editor.removeBlock(document: document, blockId: 'missing'),
      throwsStateError,
    );
    expect(
      () => editor.moveBlock(document: document, blockId: 'a', toIndex: 1),
      throwsRangeError,
    );
  });
}
