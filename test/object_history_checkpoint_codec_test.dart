import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_history_checkpoint.dart';
import 'package:bookmark_app/domain/object_history_checkpoint_codec.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = ObjectHistoryCheckpointCodec();

  group('ObjectHistoryCheckpointCodec', () {
    test('round-trips A-owned state and Relation requirements', () {
      final checkpoint = _checkpoint();

      final encoded = codec.encode(checkpoint);
      final decoded = codec.decode(encoded);

      expect(
        encoded['schemaVersion'],
        ObjectHistoryCheckpointCodec.schemaVersion,
      );
      expect(decoded.entry.objectId, 7);
      expect(decoded.entry.revisionId, 4);
      expect(decoded.entry.previousRevisionId, 3);
      expect(decoded.entry.capturedAt, DateTime.utc(2026, 9, 11, 15));
      expect(decoded.entry.source, ObjectHistorySourceKind.userMutation);
      expect(decoded.title, 'Historical title');
      expect(decoded.propertySnapshots, hasLength(2));
      expect(decoded.propertySnapshots[0].propertyId, 11);
      expect(decoded.propertySnapshots[0].type, ObjectPropertyType.text);
      expect(decoded.propertySnapshots[0].value, <String, dynamic>{
        'raw': <dynamic>['future', 1, true, null],
      });
      expect(decoded.propertySnapshots[1].propertyId, 12);
      expect(decoded.propertySnapshots[1].type, ObjectPropertyType.number);
      expect(decoded.propertySnapshots[1].value, 4.5);
      expect(decoded.body.blocks.single.type, 'future-block');
      expect(decoded.body.blocks.single.attributes['future'], 'kept');
      expect(
        decoded.relationRequirements.map(
          (requirement) => requirement.propertyId,
        ),
        <int>[21, 22],
      );

      final relationEncoded = encoded['relationPropertyIds'] as List<dynamic>;
      expect(relationEncoded, <int>[21, 22]);
      expect(encoded.toString(), isNot(contains('targetObjectIds')));
      expect(encoded.toString(), isNot(contains('object_relation_edges')));
    });

    test('rejects unknown schema, enum, timestamp, and invalid ids', () {
      final valid = codec.encode(_checkpoint());

      expect(
        () => codec.decode(<String, dynamic>{...valid, 'schemaVersion': 2}),
        throwsFormatException,
      );

      final unknownSource = _copy(valid);
      (unknownSource['entry'] as Map<String, dynamic>)['source'] =
          'futureSource';
      expect(() => codec.decode(unknownSource), throwsFormatException);

      final badTimestamp = _copy(valid);
      (badTimestamp['entry'] as Map<String, dynamic>)['capturedAt'] =
          'not-a-date';
      expect(() => codec.decode(badTimestamp), throwsFormatException);

      final badObjectId = _copy(valid);
      (badObjectId['entry'] as Map<String, dynamic>)['objectId'] = 0;
      expect(() => codec.decode(badObjectId), throwsFormatException);
    });

    test('rejects Relation/computed types in A-owned Property payload', () {
      for (final type in <ObjectPropertyType>[
        ObjectPropertyType.objectRelation,
        ObjectPropertyType.formula,
        ObjectPropertyType.rollup,
      ]) {
        final encoded = _copy(codec.encode(_checkpoint()));
        final properties = encoded['properties'] as List<dynamic>;
        (properties.first as Map<String, dynamic>)['type'] = type.name;

        expect(() => codec.decode(encoded), throwsFormatException);
      }
    });

    test('rejects duplicate Property or Relation identities', () {
      final duplicateProperty = _copy(codec.encode(_checkpoint()));
      final properties = duplicateProperty['properties'] as List<dynamic>;
      properties.add(Map<String, dynamic>.from(properties.first as Map));
      expect(() => codec.decode(duplicateProperty), throwsArgumentError);

      final duplicateRelation = _copy(codec.encode(_checkpoint()));
      final relationIds =
          duplicateRelation['relationPropertyIds'] as List<dynamic>;
      relationIds.add(relationIds.first);
      expect(() => codec.decode(duplicateRelation), throwsArgumentError);
    });

    test('rejects malformed Body and non-JSON-safe decoded values', () {
      final badBody = _copy(codec.encode(_checkpoint()));
      badBody['body'] = <String, dynamic>{
        'version': 1,
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'dup', 'type': 'paragraph'},
          <String, dynamic>{'id': 'dup', 'type': 'paragraph'},
        ],
      };
      expect(() => codec.decode(badBody), throwsFormatException);

      final badValue = _copy(codec.encode(_checkpoint()));
      final properties = badValue['properties'] as List<dynamic>;
      (properties.first as Map<String, dynamic>)['value'] = DateTime.utc(2026);
      expect(() => codec.decode(badValue), throwsFormatException);
    });
  });
}

ObjectHistoryCheckpointPayload _checkpoint() => ObjectHistoryCheckpointPayload(
  entry: ObjectHistoryEntry(
    objectId: 7,
    revisionId: 4,
    previousRevisionId: 3,
    capturedAt: DateTime.utc(2026, 9, 11, 15),
    source: ObjectHistorySourceKind.userMutation,
  ),
  title: 'Historical title',
  propertySnapshots: <ObjectHistoryPropertySnapshot>[
    ObjectHistoryPropertySnapshot.fromDefinition(
      property: _property(11, ObjectPropertyType.text),
      value: <String, dynamic>{
        'raw': <dynamic>['future', 1, true, null],
      },
    ),
    ObjectHistoryPropertySnapshot.fromDefinition(
      property: _property(12, ObjectPropertyType.number),
      value: 4.5,
    ),
  ],
  body: ObjectBodyDocument(
    blocks: <ObjectBodyBlock>[
      ObjectBodyBlock(
        id: 'future',
        type: 'future-block',
        attributes: <String, dynamic>{'future': 'kept'},
      ),
    ],
  ),
  relationRequirements: <ObjectHistoryRelationRequirement>[
    ObjectHistoryRelationRequirement.fromDefinition(
      _property(21, ObjectPropertyType.objectRelation),
    ),
    ObjectHistoryRelationRequirement.fromDefinition(
      _property(22, ObjectPropertyType.objectRelation),
    ),
  ],
);

ObjectPropertyDefinition _property(int id, ObjectPropertyType type) =>
    ObjectPropertyDefinition(
      id: id,
      objectTypeId: 1,
      name: 'Property $id',
      type: type,
      sortOrder: id,
    );

Map<String, dynamic> _copy(Map<String, dynamic> source) => <String, dynamic>{
  ...source,
  'entry': Map<String, dynamic>.from(source['entry'] as Map),
  'properties': <dynamic>[
    for (final property in source['properties'] as List<dynamic>)
      Map<String, dynamic>.from(property as Map),
  ],
  'body': Map<String, dynamic>.from(source['body'] as Map),
  'relationPropertyIds': List<dynamic>.from(
    source['relationPropertyIds'] as List<dynamic>,
  ),
};
