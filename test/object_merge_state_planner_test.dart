import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_merge_contract.dart';
import 'package:bookmark_app/domain/object_merge_state_planner.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = ObjectMergeStatePlanner();

  group('ObjectMergeStatePlanner', () {
    test('identical A-owned state produces an executable compatible preview', () {
      final survivor = _snapshot(
        objectId: 10,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{'nested': <dynamic>[1, true]},
          ),
        ],
        aliases: <String>['Alpha', 'Beta'],
      );
      final retired = _snapshot(
        objectId: 11,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{'nested': <dynamic>[1, true]},
          ),
        ],
        aliases: <String>['Alpha', 'Beta'],
      );

      final preview = planner.preview(survivor: survivor, retired: retired);

      expect(
        preview.requirements.map((requirement) => requirement.key),
        <String>['title', 'property:20', 'body', 'aliases', 'lifecycle'],
      );
      expect(preview.requirements.every((item) => !item.requiresDecision), isTrue);
      expect(preview.plan().isExecutable, isTrue);
    });

    test('title Property Body and alias differences require decisions', () {
      final survivor = _snapshot(
        objectId: 10,
        title: 'Survivor',
        bodyText: 'Survivor body',
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: 'survivor',
          ),
        ],
        aliases: <String>['Primary'],
      );
      final retired = _snapshot(
        objectId: 11,
        title: 'Retired',
        bodyText: 'Retired body',
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: 'retired',
          ),
        ],
        aliases: <String>['Secondary'],
      );

      final preview = planner.preview(survivor: survivor, retired: retired);
      final conflicts = <String, ObjectMergeRequirement>{
        for (final requirement in preview.requirements)
          if (requirement.requiresDecision) requirement.key: requirement,
      };

      expect(conflicts.keys, <String>['title', 'property:20', 'body', 'aliases']);
      expect(
        conflicts['title']!.allowedDecisions,
        <ObjectMergeDecision>{
          ObjectMergeDecision.keepSurvivor,
          ObjectMergeDecision.takeRetired,
        },
      );
      expect(
        conflicts['body']!.allowedDecisions,
        isNot(contains(ObjectMergeDecision.combine)),
      );
      expect(
        conflicts['aliases']!.allowedDecisions,
        contains(ObjectMergeDecision.combine),
      );
      expect(preview.plan().isExecutable, isFalse);

      var plan = preview.plan();
      for (final key in <String>['title', 'property:20', 'body']) {
        plan = plan.withDecision(key, ObjectMergeDecision.keepSurvivor);
      }
      plan = plan.withDecision('aliases', ObjectMergeDecision.combine);
      expect(plan.isExecutable, isTrue);
    });

    test('Property identity-set drift fails closed', () {
      final survivor = _snapshot(
        objectId: 10,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(id: 20, type: ObjectPropertyType.text, value: 'a'),
        ],
      );
      final retired = _snapshot(
        objectId: 11,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(id: 21, type: ObjectPropertyType.text, value: 'a'),
        ],
      );

      expect(
        () => planner.preview(survivor: survivor, retired: retired),
        throwsStateError,
      );
    });

    test('Property type drift fails closed before a merge plan exists', () {
      final survivor = _snapshot(
        objectId: 10,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(id: 20, type: ObjectPropertyType.text, value: '4'),
        ],
      );
      final retired = _snapshot(
        objectId: 11,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(id: 20, type: ObjectPropertyType.number, value: 4),
        ],
      );

      expect(
        () => planner.preview(survivor: survivor, retired: retired),
        throwsStateError,
      );
    });

    test('nested JSON compares structurally without numeric coercion', () {
      final equivalentSurvivor = _snapshot(
        objectId: 10,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{
              'nested': <dynamic>[
                <String, dynamic>{'a': 1, 'b': true},
              ],
            },
          ),
        ],
      );
      final equivalentRetired = _snapshot(
        objectId: 11,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{
              'nested': <dynamic>[
                <String, dynamic>{'b': true, 'a': 1},
              ],
            },
          ),
        ],
      );
      final equivalentPreview = planner.preview(
        survivor: equivalentSurvivor,
        retired: equivalentRetired,
      );
      expect(
        equivalentPreview.requirements
            .singleWhere((requirement) => requirement.key == 'property:20')
            .requiresDecision,
        isFalse,
      );

      final numericRetired = _snapshot(
        objectId: 12,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{
              'nested': <dynamic>[
                <String, dynamic>{'a': 1.0, 'b': true},
              ],
            },
          ),
        ],
      );
      final numericPreview = planner.preview(
        survivor: equivalentSurvivor,
        retired: numericRetired,
      );
      expect(
        numericPreview.requirements
            .singleWhere((requirement) => requirement.key == 'property:20')
            .requiresDecision,
        isTrue,
      );
    });

    test('Relation and computed Properties cannot enter A-owned merge state', () {
      expect(
        () => ObjectMergeValuePropertySnapshot.fromDefinition(
          property: _property(
            id: 20,
            type: ObjectPropertyType.objectRelation,
          ),
          value: <int>[1],
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectMergeValuePropertySnapshot.fromDefinition(
          property: _property(id: 21, type: ObjectPropertyType.formula),
          value: 'derived',
        ),
        throwsArgumentError,
      );
    });

    test('alias combine preserves disjoint aliases in deterministic order', () {
      final survivor = _snapshot(
        objectId: 10,
        aliases: <String>['Alpha', 'Shared'],
      );
      final retired = _snapshot(
        objectId: 11,
        aliases: <String>['Shared', 'Beta'],
      );

      expect(
        planner.combineAliases(survivor: survivor, retired: retired),
        <String>['Alpha', 'Shared', 'Beta'],
      );
    });

    test('normalized alias display collision cannot be silently combined', () {
      final survivor = _snapshot(objectId: 10, aliases: <String>['Alpha']);
      final retired = _snapshot(objectId: 11, aliases: <String>['alpha']);

      final preview = planner.preview(survivor: survivor, retired: retired);
      final aliases = preview.requirements.singleWhere(
        (requirement) => requirement.key == 'aliases',
      );
      expect(aliases.requiresDecision, isTrue);
      expect(
        aliases.allowedDecisions,
        isNot(contains(ObjectMergeDecision.combine)),
      );
      expect(
        () => planner.combineAliases(survivor: survivor, retired: retired),
        throwsStateError,
      );
    });

    test('snapshot rejects noncanonical aliases and duplicate Property ids', () {
      expect(
        () => _snapshot(objectId: 10, aliases: <String>['  Alpha  ']),
        throwsArgumentError,
      );
      final duplicate = _propertySnapshot(
        id: 20,
        type: ObjectPropertyType.text,
        value: 'a',
      );
      expect(
        () => _snapshot(
          objectId: 10,
          properties: <ObjectMergeValuePropertySnapshot>[duplicate, duplicate],
        ),
        throwsArgumentError,
      );
    });

    test('snapshot freezes nested Property payloads and alias input', () {
      final value = <String, dynamic>{
        'items': <dynamic>['before'],
      };
      final aliases = <String>['Before'];
      final survivor = _snapshot(
        objectId: 10,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: value,
          ),
        ],
        aliases: aliases,
      );
      value['items'] = <dynamic>['after'];
      aliases[0] = 'After';

      final retired = _snapshot(
        objectId: 11,
        properties: <ObjectMergeValuePropertySnapshot>[
          _propertySnapshot(
            id: 20,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{
              'items': <dynamic>['before'],
            },
          ),
        ],
        aliases: <String>['Before'],
      );

      final preview = planner.preview(survivor: survivor, retired: retired);
      expect(preview.plan().isExecutable, isTrue);
      expect(survivor.aliases, <String>['Before']);
    });

    test('cross-ObjectType planning fails closed', () {
      expect(
        () => planner.preview(
          survivor: _snapshot(objectId: 10, objectTypeId: 5),
          retired: _snapshot(objectId: 11, objectTypeId: 6),
        ),
        throwsStateError,
      );
    });

    test('Relation blockers remain B-owned and make the plan non-executable', () {
      final preview = planner.preview(
        survivor: _snapshot(objectId: 10),
        retired: _snapshot(objectId: 11),
        relationBlockers: <ObjectMergeRelationBlocker>[
          ObjectMergeRelationBlocker(
            key: 'relation:20',
            reason: 'B-owned cardinality conflict',
          ),
        ],
      );

      expect(preview.hasRelationBlockers, isTrue);
      expect(preview.plan().isExecutable, isFalse);
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
  property: _property(id: id, type: type),
  value: value,
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
