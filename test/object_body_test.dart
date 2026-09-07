import 'package:bookmark_app/domain/object_body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Object Body round-trips versioned paragraph blocks', () {
    final document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock.paragraph(id: 'b1', text: '最初の段落'),
      ],
    );

    final restored = ObjectBodyDocument.fromJson(document.toJson());

    expect(restored.version, ObjectBodyDocument.currentVersion);
    expect(restored.blocks, hasLength(1));
    expect(restored.blocks.single.id, 'b1');
    expect(restored.blocks.single.type, 'paragraph');
    expect(restored.blocks.single.text, '最初の段落');
  });

  test('unknown future block types and attributes are preserved', () {
    final restored = ObjectBodyDocument.fromJson(<String, dynamic>{
      'version': 2,
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'future-1',
          'type': 'embeddedObject',
          'attributes': <String, dynamic>{
            'objectId': 42,
            'display': 'card',
          },
        },
      ],
    });

    expect(restored.version, 2);
    expect(restored.blocks.single.type, 'embeddedObject');
    expect(restored.blocks.single.attributes['objectId'], 42);
    expect(restored.toJson()['blocks'], isA<List<dynamic>>());
  });

  test('invalid block payloads are rejected instead of silently corrupted', () {
    for (final value in <dynamic>[
      <String, dynamic>{'type': 'paragraph'},
      <String, dynamic>{'id': 'b1'},
      <String, dynamic>{'id': 1, 'type': 'paragraph'},
      <String, dynamic>{'id': 'b1', 'type': 7},
      <String, dynamic>{'id': 'b1', 'type': 'paragraph', 'text': 42},
      <String, dynamic>{
        'id': 'b1',
        'type': 'paragraph',
        'attributes': <dynamic>[],
      },
      <dynamic, dynamic>{
        'id': 'b1',
        'type': 'futureWidget',
        'attributes': <dynamic, dynamic>{1: 'lossy-key'},
      },
    ]) {
      expect(
        () => ObjectBodyBlock.fromJson(value),
        throwsFormatException,
        reason: 'Unexpectedly accepted $value',
      );
    }
  });

  test('missing optional block text and attributes keep canonical defaults', () {
    final block = ObjectBodyBlock.fromJson(<String, dynamic>{
      'id': 'future-1',
      'type': 'futureWidget',
    });

    expect(block.text, isNull);
    expect(block.attributes, isEmpty);
  });

  test('duplicate block identities are rejected on load and persistence', () {
    expect(
      () => ObjectBodyDocument.fromJson(<String, dynamic>{
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'same', 'type': 'paragraph'},
          <String, dynamic>{'id': 'same', 'type': 'futureWidget'},
        ],
      }),
      throwsFormatException,
    );

    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'same', type: 'paragraph'),
        ObjectBodyBlock(id: 'same', type: 'futureWidget'),
      ],
    );
    expect(document.toJson, throwsFormatException);
  });

  test('direct block values cannot serialize lossy id or type whitespace', () {
    const blankId = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: '   ', type: 'paragraph'),
      ],
    );
    const blankType = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'b1', type: '   '),
      ],
    );
    const paddedIdentity = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: ' b1 ', type: 'paragraph'),
      ],
    );

    expect(blankId.toJson, throwsFormatException);
    expect(blankType.toJson, throwsFormatException);
    expect(paddedIdentity.toJson, throwsFormatException);
  });
}
