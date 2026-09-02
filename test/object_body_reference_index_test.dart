import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_body_reference_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = ObjectBodyBlockFactory();

  test('indexes unique embedded Object, Database/View, and asset ids', () {
    final document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        factory.objectReference(id: 'o1', objectId: 10),
        factory.objectReference(id: 'o2', objectId: 10),
        factory.databaseView(id: 'd1', databaseId: 20, viewId: 21),
        factory.asset(
          id: 'a1',
          type: ObjectBodyBlockType.image,
          assetId: 30,
        ),
        const ObjectBodyBlock(
          id: 'future',
          type: 'futureReference',
          attributes: <String, dynamic>{'objectId': 999},
        ),
      ],
    );

    final index = ObjectBodyReferenceIndex.fromDocument(document);

    expect(index.objectIds, {10});
    expect(index.databaseIds, {20});
    expect(index.viewIds, {21});
    expect(index.assetIds, {30});
    expect(index.isEmpty, isFalse);
  });

  test('ignores malformed known references instead of inventing ids', () {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'bad',
          type: ObjectBodyBlockType.objectReference,
          attributes: <String, dynamic>{'objectId': 0},
        ),
      ],
    );

    final index = ObjectBodyReferenceIndex.fromDocument(document);
    expect(index.isEmpty, isTrue);
  });
}
