import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_history_checkpoint.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObjectHistoryCheckpointPayload', () {
    test('captures title, value Properties, Body, and Relation requirements', () {
      final body = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock.paragraph(id: 'p1', text: 'Earlier body'),
        ],
      );
      final textProperty = _property(
        id: 11,
        type: ObjectPropertyType.text,
      );
      final numberProperty = _property(
        id: 12,
        type: ObjectPropertyType.number,
      );
      final relationProperty = _property(
        id: 13,
        type: ObjectPropertyType.objectRelation,
      );

      final checkpoint = ObjectHistoryCheckpointPayload(
        entry: _entry(),
        title: 'Historical title',
        propertySnapshots: <ObjectHistoryPropertySnapshot>[
          ObjectHistoryPropertySnapshot.fromDefinition(
            property: textProperty,
            value: <String, dynamic>{
              'raw': <dynamic>['future', 1, true, null],
            },
          ),
          ObjectHistoryPropertySnapshot.fromDefinition(
            property: numberProperty,
            value: 4.5,
          ),
        ],
        body: body,
        relationRequirements: <ObjectHistoryRelationRequirement>[
          ObjectHistoryRelationRequirement.fromDefinition(relationProperty),
        ],
      );

      expect(checkpoint.entry.objectId, 7);
      expect(checkpoint.entry.revisionId, 3);
      expect(checkpoint.title, 'Historical title');
      expect(
        checkpoint.propertySnapshots.map((snapshot) => snapshot.propertyId),
        <int>[11, 12],
      );
      expect(
        checkpoint.relationRequirements.single.propertyId,
        relationProperty.id,
      );
      expect(checkpoint.body.blocks.single.text, 'Earlier body');
    });

    test('Property identity must be positive and unique', () {
      expect(
        () => ObjectHistoryPropertySnapshot.fromDefinition(
          property: _property(id: 0, type: ObjectPropertyType.text),
          value: 'bad',
        ),
        throwsArgumentError,
      );

      final property = _property(id: 11, type: ObjectPropertyType.text);
      expect(
        () => ObjectHistoryCheckpointPayload(
          entry: _entry(),
          title: 'Duplicate',
          propertySnapshots: <ObjectHistoryPropertySnapshot>[
            ObjectHistoryPropertySnapshot.fromDefinition(
              property: property,
              value: 'first',
            ),
            ObjectHistoryPropertySnapshot.fromDefinition(
              property: property,
              value: 'second',
            ),
          ],
          body: const ObjectBodyDocument(),
        ),
        throwsArgumentError,
      );
    });

    test('Relation and computed Properties cannot become A value snapshots', () {
      final relation = _property(
        id: 21,
        type: ObjectPropertyType.objectRelation,
      );
      final formula = _property(id: 22, type: ObjectPropertyType.formula);
      final text = _property(id: 23, type: ObjectPropertyType.text);

      expect(
        () => ObjectHistoryPropertySnapshot.fromDefinition(
          property: relation,
          value: <int>[9],
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectHistoryPropertySnapshot.fromDefinition(
          property: formula,
          value: 42,
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectHistoryRelationRequirement.fromDefinition(text),
        throwsArgumentError,
      );
      expect(
        ObjectHistoryRelationRequirement.fromDefinition(relation).propertyId,
        21,
      );
    });

    test('JSON-safe Property values are deeply immutable after capture', () {
      final source = <String, dynamic>{
        'items': <dynamic>[
          'alpha',
          <String, dynamic>{'enabled': true},
        ],
      };
      final snapshot = ObjectHistoryPropertySnapshot.fromDefinition(
        property: _property(id: 31, type: ObjectPropertyType.text),
        value: source,
      );

      (source['items'] as List<dynamic>).add('later');
      (source['items'] as List<dynamic>)[1]['enabled'] = false;

      final frozen = snapshot.value as Map<String, dynamic>;
      final items = frozen['items'] as List<dynamic>;
      expect(items, hasLength(2));
      expect((items[1] as Map<String, dynamic>)['enabled'], isTrue);
      expect(() => frozen['new'] = 'value', throwsUnsupportedError);
      expect(() => items.add('value'), throwsUnsupportedError);
    });

    test('non-JSON-safe or non-finite Property values fail closed', () {
      final property = _property(id: 41, type: ObjectPropertyType.text);

      expect(
        () => ObjectHistoryPropertySnapshot.fromDefinition(
          property: property,
          value: DateTime.utc(2026),
        ),
        throwsFormatException,
      );
      expect(
        () => ObjectHistoryPropertySnapshot.fromDefinition(
          property: property,
          value: <dynamic, dynamic>{1: 'bad-key'},
        ),
        throwsFormatException,
      );
      expect(
        () => ObjectHistoryPropertySnapshot.fromDefinition(
          property: property,
          value: double.nan,
        ),
        throwsFormatException,
      );
    });

    test('Body uses canonical validation and cannot mutate captured state', () {
      final attributes = <String, dynamic>{'checked': false};
      final body = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'p1',
            type: 'future-block',
            attributes: attributes,
          ),
        ],
      );
      final checkpoint = ObjectHistoryCheckpointPayload(
        entry: _entry(),
        title: 'Body history',
        propertySnapshots: const <ObjectHistoryPropertySnapshot>[],
        body: body,
      );

      attributes['checked'] = true;
      final firstRead = checkpoint.body;
      expect(firstRead.blocks.single.attributes['checked'], isFalse);
      firstRead.blocks.single.attributes['local'] = true;
      expect(checkpoint.body.blocks.single.attributes.containsKey('local'), isFalse);

      final malformed = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock.paragraph(id: 'dup'),
          ObjectBodyBlock.paragraph(id: 'dup'),
        ],
      );
      expect(
        () => ObjectHistoryCheckpointPayload(
          entry: _entry(),
          title: 'Malformed Body',
          propertySnapshots: const <ObjectHistoryPropertySnapshot>[],
          body: malformed,
        ),
        throwsFormatException,
      );
    });

    test('empty title and duplicate Relation requirements fail closed', () {
      final relation = _property(
        id: 51,
        type: ObjectPropertyType.objectRelation,
      );
      final requirement = ObjectHistoryRelationRequirement.fromDefinition(
        relation,
      );

      expect(
        () => ObjectHistoryCheckpointPayload(
          entry: _entry(),
          title: '   ',
          propertySnapshots: const <ObjectHistoryPropertySnapshot>[],
          body: const ObjectBodyDocument(),
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectHistoryCheckpointPayload(
          entry: _entry(),
          title: 'Relations',
          propertySnapshots: const <ObjectHistoryPropertySnapshot>[],
          body: const ObjectBodyDocument(),
          relationRequirements: <ObjectHistoryRelationRequirement>[
            requirement,
            requirement,
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}

ObjectHistoryEntry _entry() => ObjectHistoryEntry(
  objectId: 7,
  revisionId: 3,
  previousRevisionId: 2,
  capturedAt: DateTime.utc(2026, 9, 11, 7),
  source: ObjectHistorySourceKind.userMutation,
);

ObjectPropertyDefinition _property({
  required int id,
  required ObjectPropertyType type,
}) => ObjectPropertyDefinition(
  id: id,
  objectTypeId: 5,
  name: 'Property $id',
  type: type,
  sortOrder: id,
  config: type == ObjectPropertyType.objectRelation
      ? const <String, dynamic>{'targetObjectTypeId': 5, 'multiple': true}
      : const <String, dynamic>{},
);
