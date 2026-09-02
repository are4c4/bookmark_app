import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_body_block_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = ObjectBodyBlockFactory();
  const validator = ObjectBodyBlockValidator();

  test('factory creates typed heading/checklist/code blocks', () {
    final heading = factory.heading(id: 'h1', level: 2, text: 'Title');
    final checklist = factory.checklist(id: 'c1', text: 'Done', checked: true);
    final code = factory.code(id: 'code1', text: 'print(1)', language: ' dart ');

    expect(heading.type, ObjectBodyBlockType.heading);
    expect(heading.attributes[ObjectBodyBlockAttribute.level], 2);
    expect(checklist.attributes[ObjectBodyBlockAttribute.checked], isTrue);
    expect(code.attributes[ObjectBodyBlockAttribute.language], 'dart');
    validator.validateDocument(
      ObjectBodyDocument(blocks: <ObjectBodyBlock>[heading, checklist, code]),
    );
  });

  test('reference blocks expose typed ids and round-trip through JSON', () {
    final object = factory.objectReference(id: 'o1', objectId: 42);
    final database = factory.databaseView(id: 'd1', databaseId: 5, viewId: 9);
    final image = factory.asset(
      id: 'i1',
      type: ObjectBodyBlockType.image,
      assetId: 17,
      caption: 'cover',
    );

    final decodedObject = ObjectBodyBlock.fromJson(object.toJson());
    final decodedDatabase = ObjectBodyBlock.fromJson(database.toJson());
    final decodedImage = ObjectBodyBlock.fromJson(image.toJson());

    expect(decodedObject.referencedObjectId, 42);
    expect(decodedDatabase.referencedDatabaseId, 5);
    expect(decodedDatabase.referencedViewId, 9);
    expect(decodedImage.referencedAssetId, 17);
    validator.validateDocument(
      ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          decodedObject,
          decodedDatabase,
          decodedImage,
        ],
      ),
    );
  });

  test('factory rejects invalid heading and reference ids', () {
    expect(
      () => factory.heading(id: 'h', level: 4),
      throwsA(isA<RangeError>()),
    );
    expect(
      () => factory.objectReference(id: 'o', objectId: 0),
      throwsArgumentError,
    );
    expect(
      () => factory.databaseView(id: 'd', databaseId: -1),
      throwsArgumentError,
    );
  });

  test('validator rejects malformed known references and duplicate ids', () {
    const malformed = ObjectBodyBlock(
      id: 'ref',
      type: ObjectBodyBlockType.objectReference,
      attributes: <String, dynamic>{ObjectBodyBlockAttribute.objectId: 0},
    );
    expect(() => validator.validate(malformed), throwsFormatException);

    const duplicate = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'same', type: ObjectBodyBlockType.paragraph),
        ObjectBodyBlock(id: 'same', type: ObjectBodyBlockType.divider),
      ],
    );
    expect(() => validator.validateDocument(duplicate), throwsFormatException);
  });

  test('unknown future block remains accepted and round-trippable', () {
    const future = ObjectBodyBlock(
      id: 'future',
      type: 'futureWidget',
      text: 'opaque',
      attributes: <String, dynamic>{'schema': 7, 'payload': 'keep'},
    );

    validator.validate(future);
    final decoded = ObjectBodyBlock.fromJson(future.toJson());
    expect(decoded.isKnownType, isFalse);
    expect(decoded.toJson(), future.toJson());
  });
}
