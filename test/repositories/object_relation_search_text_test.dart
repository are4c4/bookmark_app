import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_relation_search_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourceObjectId = 7;
  final now = DateTime.utc(2026, 9, 7);

  ObjectPropertyDefinition relationProperty({
    required int id,
    bool searchable = true,
  }) => ObjectPropertyDefinition(
        id: id,
        objectTypeId: 1,
        name: 'Related',
        type: ObjectPropertyType.objectRelation,
        sortOrder: id,
        config: <String, dynamic>{
          'targetObjectTypeId': 2,
          'multiple': true,
          if (!searchable) 'searchable': false,
        },
      );

  ResolvedOutgoingRelation resolved({
    required ObjectPropertyDefinition property,
    required int targetId,
    required int position,
    required String title,
  }) => ResolvedOutgoingRelation(
        edge: ObjectRelationEdge(
          sourceObjectId: sourceObjectId,
          propertyId: property.id,
          targetObjectId: targetId,
          position: position,
        ),
        property: property,
        targetObject: AppObject(
          id: targetId,
          objectTypeId: 2,
          title: title,
          createdAt: now,
          updatedAt: now,
        ),
      );

  test('emits only canonical target labels in deterministic relation order', () {
    final primary = relationProperty(id: 10);
    final secondary = relationProperty(id: 20);
    final text = buildObjectRelationSearchText(<ResolvedOutgoingRelation>[
      resolved(
        property: secondary,
        targetId: 300,
        position: 0,
        title: '  Grace Hopper  ',
      ),
      resolved(
        property: primary,
        targetId: 200,
        position: 1,
        title: 'Alan Turing',
      ),
      resolved(
        property: primary,
        targetId: 100,
        position: 0,
        title: 'Ada Lovelace',
      ),
    ]);

    expect(text, 'Ada Lovelace\nAlan Turing\nGrace Hopper');
    expect(text, isNot(contains('100')));
    expect(text, isNot(contains('200')));
    expect(text, isNot(contains('300')));
  });

  test('skips blank labels and explicit searchable false Relations', () {
    final searchable = relationProperty(id: 10);
    final hidden = relationProperty(id: 20, searchable: false);

    expect(
      buildObjectRelationSearchText(<ResolvedOutgoingRelation>[
        resolved(
          property: searchable,
          targetId: 100,
          position: 0,
          title: '   ',
        ),
        resolved(
          property: hidden,
          targetId: 200,
          position: 0,
          title: 'Private relation label',
        ),
      ]),
      isEmpty,
    );
  });
}
