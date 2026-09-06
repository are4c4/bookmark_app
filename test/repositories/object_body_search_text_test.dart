import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/repositories/object_body_search_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projects rich Body text in persisted order', () {
    const body = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'heading-1',
          type: ObjectBodyBlockType.heading,
          text: '  Searchable heading  ',
        ),
        ObjectBodyBlock(
          id: 'paragraph-1',
          type: ObjectBodyBlockType.paragraph,
          text: 'Paragraph body',
        ),
        ObjectBodyBlock(
          id: 'code-1',
          type: ObjectBodyBlockType.code,
          text: 'final answer = 42;',
          attributes: <String, dynamic>{
            ObjectBodyBlockAttribute.language: 'dart',
          },
        ),
      ],
    );

    expect(
      buildObjectBodySearchText(body),
      'Searchable heading\nParagraph body\nfinal answer = 42;',
    );
  });

  test('includes asset captions without leaking structural ids', () {
    const body = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'image-99',
          type: ObjectBodyBlockType.image,
          attributes: <String, dynamic>{
            ObjectBodyBlockAttribute.assetId: 987654,
            ObjectBodyBlockAttribute.caption: 'Northern lights photo',
          },
        ),
        ObjectBodyBlock(
          id: 'object-ref-1',
          type: ObjectBodyBlockType.objectReference,
          text: 'Referenced person',
          attributes: <String, dynamic>{
            ObjectBodyBlockAttribute.objectId: 123456,
          },
        ),
        ObjectBodyBlock(
          id: 'database-view-1',
          type: ObjectBodyBlockType.databaseView,
          attributes: <String, dynamic>{
            ObjectBodyBlockAttribute.databaseId: 24680,
            ObjectBodyBlockAttribute.viewId: 13579,
          },
        ),
      ],
    );

    final text = buildObjectBodySearchText(body);

    expect(text, 'Northern lights photo\nReferenced person');
    expect(text, isNot(contains('987654')));
    expect(text, isNot(contains('123456')));
    expect(text, isNot(contains('24680')));
    expect(text, isNot(contains('13579')));
  });

  test('keeps user text from unknown future block kinds searchable', () {
    const body = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'future-1',
          type: 'futureRichBlock',
          text: 'Future user-authored text',
          attributes: <String, dynamic>{
            'opaqueMachineField': 'do-not-index',
          },
        ),
      ],
    );

    expect(buildObjectBodySearchText(body), 'Future user-authored text');
  });

  test('ignores blank fragments and avoids duplicate caption text', () {
    const body = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'blank',
          type: ObjectBodyBlockType.paragraph,
          text: '   ',
        ),
        ObjectBodyBlock(
          id: 'caption',
          type: ObjectBodyBlockType.image,
          text: 'Same label',
          attributes: <String, dynamic>{
            ObjectBodyBlockAttribute.caption: 'Same label',
          },
        ),
      ],
    );

    expect(buildObjectBodySearchText(body), 'Same label');
  });
}
