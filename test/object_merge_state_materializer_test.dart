import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_merge_contract.dart';
import 'package:bookmark_app/domain/object_merge_state_materializer.dart';
import 'package:bookmark_app/domain/object_merge_state_planner.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const materializer = ObjectMergeStateMaterializer();

  group('ObjectMergeStateMaterializer', () {
    test('no-conflict plan materializes the prepared survivor state', () {
      final survivor = _snapshot(
        objectId: 10,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{'value': 'same'},
          ),
        ],
        aliases: <String>['Alpha'],
      );
      final retired = _snapshot(
        objectId: 11,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{'value': 'same'},
          ),
        ],
        aliases: <String>['Alpha'],
      );
      final prepared = ObjectMergePreparedState.prepare(
        survivor: survivor,
        retired: retired,
      );

      final result = materializer.materialize(
        prepared: prepared,
        plan: prepared.plan(),
      );

      expect(result.objectId, survivor.objectId);
      expect(result.objectTypeId, survivor.objectTypeId);
      expect(result.title, survivor.title);
      expect(result.aliases, survivor.aliases);
      expect(result.body.toJson(), survivor.body.toJson());
      expect(result.propertySnapshots.single.value, <String, dynamic>{
        'value': 'same',
      });
    });

    test('mixed decisions change only explicitly selected A-owned state', () {
      final survivor = _snapshot(
        objectId: 10,
        title: 'Survivor title',
        bodyText: 'Survivor body',
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: 'survivor text',
          ),
          _propertySnapshot(id: 21, type: ObjectPropertyType.number, value: 1),
        ],
        aliases: <String>['Alpha'],
      );
      final retired = _snapshot(
        objectId: 11,
        title: 'Retired title',
        bodyText: 'Retired body',
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: 'retired text',
          ),
          _propertySnapshot(id: 21, type: ObjectPropertyType.number, value: 2),
        ],
        aliases: <String>['Beta'],
      );
      final prepared = ObjectMergePreparedState.prepare(
        survivor: survivor,
        retired: retired,
      );
      final plan = prepared
          .plan()
          .withDecision('title', ObjectMergeDecision.takeRetired)
          .withDecision('property:20', ObjectMergeDecision.takeRetired)
          .withDecision('property:21', ObjectMergeDecision.keepSurvivor)
          .withDecision('body', ObjectMergeDecision.keepSurvivor)
          .withDecision('aliases', ObjectMergeDecision.combine);

      final result = materializer.materialize(prepared: prepared, plan: plan);
      final properties = <int, ObjectMergeValuePropertySnapshot>{
        for (final property in result.propertySnapshots)
          property.propertyId: property,
      };

      expect(result.objectId, 10);
      expect(result.objectTypeId, 5);
      expect(result.title, 'Retired title');
      expect(properties[20]!.value, 'retired text');
      expect(properties[21]!.value, 1);
      expect(result.body.toJson(), survivor.body.toJson());
      expect(result.aliases, <String>['Alpha', 'Beta']);
    });

    test('plan from another prepared context fails even with the same ids', () {
      final first = ObjectMergePreparedState.prepare(
        survivor: _snapshot(objectId: 10, title: 'First survivor'),
        retired: _snapshot(objectId: 11, title: 'First retired'),
      );
      final second = ObjectMergePreparedState.prepare(
        survivor: _snapshot(objectId: 10, title: 'Second survivor'),
        retired: _snapshot(objectId: 11, title: 'Second retired'),
      );
      final stalePlan = first.plan().withDecision(
        'title',
        ObjectMergeDecision.keepSurvivor,
      );

      expect(
        () => materializer.materialize(prepared: second, plan: stalePlan),
        throwsStateError,
      );
    });

    test('Relation blockers keep materialization non-executable', () {
      final prepared = ObjectMergePreparedState.prepare(
        survivor: _snapshot(objectId: 10),
        retired: _snapshot(objectId: 11),
        relationBlockers: <ObjectMergeRelationBlocker>[
          ObjectMergeRelationBlocker(
            key: 'relation:20',
            reason: 'B-owned cardinality conflict',
          ),
        ],
      );
      final plan = prepared.plan();

      expect(plan.isExecutable, isFalse);
      expect(
        () => materializer.materialize(prepared: prepared, plan: plan),
        throwsStateError,
      );
    });

    test('retired numeric representation is preserved without coercion', () {
      final survivor = _snapshot(
        objectId: 10,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(id: 20, type: ObjectPropertyType.number, value: 1),
        ],
      );
      final retired = _snapshot(
        objectId: 11,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.number,
            value: 1.0,
          ),
        ],
      );
      final prepared = ObjectMergePreparedState.prepare(
        survivor: survivor,
        retired: retired,
      );
      final plan = prepared.plan().withDecision(
        'property:20',
        ObjectMergeDecision.takeRetired,
      );
      final result = materializer.materialize(prepared: prepared, plan: plan);

      expect(result.propertySnapshots.single.value, isA<double>());
      expect(result.propertySnapshots.single.value, 1.0);
    });

    test('unresolved A-owned decisions cannot be materialized', () {
      final prepared = ObjectMergePreparedState.prepare(
        survivor: _snapshot(objectId: 10, bodyText: 'Survivor'),
        retired: _snapshot(objectId: 11, bodyText: 'Retired'),
      );
      final plan = prepared.plan();

      expect(plan.isExecutable, isFalse);
      expect(
        () => materializer.materialize(prepared: prepared, plan: plan),
        throwsStateError,
      );
    });

    test('materialized collections remain immutable snapshots', () {
      final prepared = ObjectMergePreparedState.prepare(
        survivor: _snapshot(
          objectId: 10,
          aliases: <String>['Alpha'],
          properties: <ObjectMergeValuePropertySnapshot>[
            _propertySnapshot(
              id: 20,
              type: ObjectPropertyType.text,
              value: <String, dynamic>{
                'nested': <dynamic>['value'],
              },
            ),
          ],
        ),
        retired: _snapshot(
          objectId: 11,
          aliases: <String>['Alpha'],
          properties: <ObjectMergeValuePropertySnapshot>[
            _propertySnapshot(
              id: 20,
              type: ObjectPropertyType.text,
              value: <String, dynamic>{
                'nested': <dynamic>['value'],
              },
            ),
          ],
        ),
      );

      final result = materializer.materialize(
        prepared: prepared,
        plan: prepared.plan(),
      );

      expect(() => result.aliases.add('Beta'), throwsUnsupportedError);
      expect(
        () => result.propertySnapshots.add(
          _propertySnapshot(
            id: 21,
            type: ObjectPropertyType.text,
            value: 'extra',
          ),
        ),
        throwsUnsupportedError,
      );
      final value =
          result.propertySnapshots.single.value as Map<String, dynamic>;
      expect(() => value['extra'] = true, throwsUnsupportedError);
    });
  });
}

ObjectMergeStateSnapshot _snapshot({
  required int objectId,
  int objectTypeId = 5,
  String title = 'Same title',
  List<ObjectMergeValuePropertySnapshot> properties =
      const <ObjectMergeValuePropertySnapshot>[],
  String bodyText = 'Same body',
  List<String> aliases = const <String>[],
}) => ObjectMergeStateSnapshot(
  objectId: objectId,
  objectTypeId: objectTypeId,
  title: title,
  propertySnapshots: properties,
  body: ObjectBodyDocument(
    blocks: <ObjectBodyBlock>[
      ObjectBodyBlock.paragraph(id: 'p1', text: bodyText),
    ],
  ),
  aliases: aliases,
);

ObjectMergeValuePropertySnapshot _propertySnapshot({
  required int id,
  required ObjectPropertyType type,
  required dynamic value,
}) => ObjectMergeValuePropertySnapshot.fromDefinition(
  property: ObjectPropertyDefinition(
    id: id,
    objectTypeId: 5,
    name: 'Property $id',
    type: type,
    sortOrder: id,
    config: const <String, dynamic>{},
  ),
  value: value,
);
