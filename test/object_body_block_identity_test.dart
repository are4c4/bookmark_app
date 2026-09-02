import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allocator skips used ids and normalizes semantic prefixes', () {
    const document = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(id: 'note-block-1', type: 'paragraph'),
      ObjectBodyBlock(id: 'note-block-2', type: 'paragraph'),
      ObjectBodyBlock(id: 'other-1', type: 'paragraph'),
    ]);

    const allocator = ObjectBodyBlockIdAllocator();
    expect(allocator.next(document, prefix: ' Note Block '), 'note-block-3');
    expect(allocator.next(document, prefix: '***'), 'block-1');
  });

  test('duplicator preserves unknown payload while assigning a new id', () {
    const source = ObjectBodyBlock(
      id: 'future-1',
      type: 'futureWidget',
      text: 'payload',
      attributes: {'nested': {'keep': true}, 'v': 7},
    );

    final duplicate = const ObjectBodyBlockDuplicator().duplicate(
      source: source,
      newId: 'future-2',
    );

    expect(duplicate.id, 'future-2');
    expect(duplicate.type, source.type);
    expect(duplicate.text, source.text);
    expect(duplicate.attributes, source.attributes);
    expect(duplicate.toJson(), {
      'id': 'future-2',
      'type': 'futureWidget',
      'text': 'payload',
      'attributes': {'nested': {'keep': true}, 'v': 7},
    });
  });

  test('duplicator rejects blank or reused identities', () {
    const source = ObjectBodyBlock(id: 'same', type: 'paragraph');
    const duplicator = ObjectBodyBlockDuplicator();

    expect(
      () => duplicator.duplicate(source: source, newId: ' '),
      throwsArgumentError,
    );
    expect(
      () => duplicator.duplicate(source: source, newId: 'same'),
      throwsArgumentError,
    );
  });
}
