import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adapter = ObjectBodyPlainTextAdapter();

  test('paragraph-only Body can round-trip through plain text', () {
    final document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock.paragraph(id: 'p1', text: 'first'),
        ObjectBodyBlock.paragraph(id: 'p2', text: 'second'),
      ],
    );

    expect(adapter.read(document), 'first\n\nsecond');

    final updated = adapter.write(
      document: document,
      text: 'changed\n\nsecond\n\nthird',
      blockIdForIndex: (index) => 'new-$index',
    );

    expect(updated.blocks.map((block) => block.id).toList(), <String>[
      'p1',
      'p2',
      'new-2',
    ]);
    expect(updated.blocks.map((block) => block.text).toList(), <String?>[
      'changed',
      'second',
      'third',
    ]);
  });

  test('plain-text editing refuses a Body with richer blocks', () {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'code-1', type: 'code', text: 'print(1)'),
      ],
    );

    expect(adapter.canEdit(document), isFalse);
    expect(() => adapter.read(document), throwsStateError);
    expect(
      () => adapter.write(
        document: document,
        text: 'replacement',
        blockIdForIndex: (index) => 'p-$index',
      ),
      throwsStateError,
    );
  });

  test('empty plain text clears paragraph blocks only', () {
    final document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock.paragraph(id: 'p1', text: 'remove me'),
      ],
    );

    final updated = adapter.write(
      document: document,
      text: '',
      blockIdForIndex: (index) => 'unused-$index',
    );

    expect(updated.blocks, isEmpty);
  });
}
