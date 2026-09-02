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
    expect(
      () => ObjectBodyBlock.fromJson(<String, dynamic>{'type': 'paragraph'}),
      throwsFormatException,
    );
    expect(
      () => ObjectBodyBlock.fromJson(<String, dynamic>{'id': 'b1'}),
      throwsFormatException,
    );
  });
}
