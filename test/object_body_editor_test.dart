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

  test('split paragraph preserves source metadata and unrelated blocks', () {
    const future = ObjectBodyBlock(
      id: 'future',
      type: 'embed',
      attributes: <String, dynamic>{'objectId': 42},
    );
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'p1',
          type: 'paragraph',
          text: 'hello world',
          attributes: <String, dynamic>{'align': 'center'},
        ),
        future,
      ],
    );

    final split = editor.splitParagraph(
      document: document,
      blockId: 'p1',
      newBlockId: 'p2',
      selectionStart: 5,
      selectionEnd: 5,
    );

    expect(split.blocks.map((block) => block.id), ['p1', 'p2', 'future']);
    expect(split.blocks[0].text, 'hello');
    expect(split.blocks[0].attributes, {'align': 'center'});
    expect(split.blocks[1].type, 'paragraph');
    expect(split.blocks[1].text, ' world');
    expect(split.blocks[1].attributes, isEmpty);
    expect(split.blocks[2].toJson(), future.toJson());
  });

  test('split paragraph replaces selected text with the paragraph break', () {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'hello brave world'),
      ],
    );

    final split = editor.splitParagraph(
      document: document,
      blockId: 'p1',
      newBlockId: 'p2',
      selectionStart: 5,
      selectionEnd: 11,
    );

    expect(split.blocks[0].text, 'hello');
    expect(split.blocks[1].text, ' world');
  });

  test('Backspace merge combines adjacent plain paragraphs', () {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'hello'),
        ObjectBodyBlock(id: 'p2', type: 'paragraph', text: ' world'),
        ObjectBodyBlock(id: 'p3', type: 'paragraph', text: 'after'),
      ],
    );

    final merged = editor.mergeParagraphIntoPrevious(
      document: document,
      blockId: 'p2',
    );

    expect(merged.blocks.map((block) => block.id), ['p1', 'p3']);
    expect(merged.blocks[0].text, 'hello world');
    expect(merged.blocks[1].text, 'after');
  });

  test('Backspace merge leaves unsafe block boundaries unchanged', () {
    const first = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'first'),
      ],
    );
    expect(
      identical(
        editor.mergeParagraphIntoPrevious(document: first, blockId: 'p1'),
        first,
      ),
      isTrue,
    );

    const styled = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'p1',
          type: 'paragraph',
          text: 'styled',
          attributes: <String, dynamic>{'align': 'center'},
        ),
        ObjectBodyBlock(id: 'p2', type: 'paragraph', text: 'plain'),
      ],
    );
    expect(
      identical(
        editor.mergeParagraphIntoPrevious(document: styled, blockId: 'p2'),
        styled,
      ),
      isTrue,
    );

    const headingBoundary = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'h1', type: 'heading', text: 'Heading'),
        ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'plain'),
      ],
    );
    expect(
      identical(
        editor.mergeParagraphIntoPrevious(
          document: headingBoundary,
          blockId: 'p1',
        ),
        headingBoundary,
      ),
      isTrue,
    );
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
        ObjectBodyBlock(id: 'a', type: 'paragraph', text: 'safe'),
        ObjectBodyBlock(id: 'h', type: 'heading', text: 'Heading'),
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
      () => editor.moveBlock(document: document, blockId: 'a', toIndex: 2),
      throwsRangeError,
    );
    expect(
      () => editor.splitParagraph(
        document: document,
        blockId: 'h',
        newBlockId: 'new',
        selectionStart: 0,
        selectionEnd: 0,
      ),
      throwsStateError,
    );
    expect(
      () => editor.splitParagraph(
        document: document,
        blockId: 'a',
        newBlockId: 'new',
        selectionStart: 5,
        selectionEnd: 5,
      ),
      throwsRangeError,
    );
    expect(
      () => editor.splitParagraph(
        document: document,
        blockId: 'a',
        newBlockId: 'new',
        selectionStart: 3,
        selectionEnd: 2,
      ),
      throwsRangeError,
    );
    expect(
      () => editor.splitParagraph(
        document: document,
        blockId: 'a',
        newBlockId: 'h',
        selectionStart: 2,
        selectionEnd: 2,
      ),
      throwsStateError,
    );
  });
}
