import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_history_checkpoint.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:bookmark_app/domain/object_history_restore_planner.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = ObjectHistoryCheckpointRestorePlanner();

  group('ObjectHistoryCheckpointRestorePlanner', () {
    test('whole restore previews changed and unchanged A-owned fields', () {
      final historical = _checkpoint(
        revisionId: 2,
        title: 'Earlier title',
        properties: <ObjectHistoryPropertySnapshot>[
          _snapshot(id: 11, type: ObjectPropertyType.text, value: 'same'),
          _snapshot(
            id: 12,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{
              'nested': <dynamic>['earlier', true],
            },
          ),
        ],
        bodyText: 'Earlier body',
      );
      final current = _checkpoint(
        revisionId: 5,
        title: 'Current title',
        properties: <ObjectHistoryPropertySnapshot>[
          _snapshot(id: 11, type: ObjectPropertyType.text, value: 'same'),
          _snapshot(
            id: 12,
            type: ObjectPropertyType.text,
            value: <String, dynamic>{
              'nested': <dynamic>['current', true],
            },
          ),
        ],
        bodyText: 'Earlier body',
      );

      final preview = planner.preview(
        historical: historical,
        current: current,
        scope: ObjectHistoryRestoreScope.wholeObject(),
      );

      expect(preview.blockers, isEmpty);
      expect(preview.relationBlockers, isEmpty);
      expect(preview.decisions.map((decision) => decision.target.key), <String>[
        'title',
        'property:11',
        'property:12',
        'body',
      ]);
      expect(
        preview.decisions.map((decision) => decision.kind),
        <ObjectHistoryRestoreDecisionKind>[
          ObjectHistoryRestoreDecisionKind.restore,
          ObjectHistoryRestoreDecisionKind.noChange,
          ObjectHistoryRestoreDecisionKind.restore,
          ObjectHistoryRestoreDecisionKind.noChange,
        ],
      );
      expect(preview.hasChanges, isTrue);
    });

    test('selective restore ignores unrelated newer Property state', () {
      final historical = _checkpoint(
        revisionId: 2,
        title: 'Earlier title',
        properties: <ObjectHistoryPropertySnapshot>[
          _snapshot(id: 11, type: ObjectPropertyType.text, value: 'earlier'),
        ],
      );
      final current = _checkpoint(
        revisionId: 6,
        title: 'Current title',
        properties: <ObjectHistoryPropertySnapshot>[
          _snapshot(id: 11, type: ObjectPropertyType.text, value: 'current'),
          _snapshot(id: 12, type: ObjectPropertyType.number, value: 42),
        ],
      );

      final preview = planner.preview(
        historical: historical,
        current: current,
        scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
          ObjectHistoryFieldTarget.title(),
        ]),
      );

      expect(preview.blockers, isEmpty);
      expect(preview.relationBlockers, isEmpty);
      expect(preview.decisions, hasLength(1));
      expect(preview.decisions.single.target.key, 'title');
      expect(preview.decisions.single.needsRestore, isTrue);
    });

    test('whole restore blocks on added or missing value Property ids', () {
      final preview = planner.preview(
        historical: _checkpoint(
          revisionId: 2,
          properties: <ObjectHistoryPropertySnapshot>[
            _snapshot(id: 11, type: ObjectPropertyType.text, value: 'old'),
          ],
        ),
        current: _checkpoint(
          revisionId: 5,
          properties: <ObjectHistoryPropertySnapshot>[
            _snapshot(id: 12, type: ObjectPropertyType.text, value: 'new'),
          ],
        ),
        scope: ObjectHistoryRestoreScope.wholeObject(),
      );

      expect(preview.blockers.map((blocker) => blocker.key), <String>[
        'property:11',
        'property:12',
      ]);
      expect(preview.hasAOwnedBlockers, isTrue);
      expect(
        () => preview.planForExecution(actualCurrentRevisionId: 5),
        throwsStateError,
      );
    });

    test('Property type drift blocks restore before mutation planning', () {
      final preview = planner.preview(
        historical: _checkpoint(
          revisionId: 2,
          properties: <ObjectHistoryPropertySnapshot>[
            _snapshot(id: 11, type: ObjectPropertyType.text, value: '4'),
          ],
        ),
        current: _checkpoint(
          revisionId: 5,
          properties: <ObjectHistoryPropertySnapshot>[
            _snapshot(id: 11, type: ObjectPropertyType.number, value: 4),
          ],
        ),
        scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
          ObjectHistoryFieldTarget.property(11),
        ]),
      );

      expect(preview.decisions, isEmpty);
      expect(preview.blockers.single.key, 'property:11');
      expect(preview.blockers.single.reason, contains('changed type'));
    });

    test('Relation requirements stay delegated to B-owned blockers', () {
      final preview = planner.preview(
        historical: _checkpoint(revisionId: 2, relationPropertyIds: <int>[21]),
        current: _checkpoint(revisionId: 5, relationPropertyIds: <int>[21]),
        scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
          ObjectHistoryFieldTarget.property(21),
        ]),
      );

      expect(preview.blockers, isEmpty);
      expect(preview.decisions, isEmpty);
      expect(preview.relationBlockers.single.key, 'property:21');
      final executionPlan = preview.planForExecution(
        actualCurrentRevisionId: 5,
      );
      expect(executionPlan.hasCurrentRevisionConflict, isFalse);
      expect(executionPlan.isExecutable, isFalse);
    });

    test('nested JSON values compare structurally without source identity', () {
      final historicalValue = <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'enabled': true, 'count': 2},
        ],
      };
      final currentValue = <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'count': 2, 'enabled': true},
        ],
      };
      final preview = planner.preview(
        historical: _checkpoint(
          revisionId: 2,
          properties: <ObjectHistoryPropertySnapshot>[
            _snapshot(
              id: 11,
              type: ObjectPropertyType.text,
              value: historicalValue,
            ),
          ],
        ),
        current: _checkpoint(
          revisionId: 5,
          properties: <ObjectHistoryPropertySnapshot>[
            _snapshot(
              id: 11,
              type: ObjectPropertyType.text,
              value: currentValue,
            ),
          ],
        ),
        scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
          ObjectHistoryFieldTarget.property(11),
        ]),
      );

      expect(preview.blockers, isEmpty);
      expect(preview.decisions.single.needsRestore, isFalse);
    });

    test('JSON numeric representation is compared without coercion', () {
      final preview = planner.preview(
        historical: _checkpoint(
          revisionId: 2,
          properties: <ObjectHistoryPropertySnapshot>[
            _snapshot(id: 11, type: ObjectPropertyType.number, value: 1),
          ],
        ),
        current: _checkpoint(
          revisionId: 5,
          properties: <ObjectHistoryPropertySnapshot>[
            _snapshot(id: 11, type: ObjectPropertyType.number, value: 1.0),
          ],
        ),
        scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
          ObjectHistoryFieldTarget.property(11),
        ]),
      );

      expect(preview.blockers, isEmpty);
      expect(preview.decisions.single.needsRestore, isTrue);
    });

    test(
      'execution plan keeps prepared-current revision as the stale guard',
      () {
        final preview = planner.preview(
          historical: _checkpoint(revisionId: 2, title: 'Earlier'),
          current: _checkpoint(revisionId: 5, title: 'Current'),
          scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
            ObjectHistoryFieldTarget.title(),
          ]),
        );

        final fresh = preview.planForExecution(actualCurrentRevisionId: 5);
        expect(fresh.isExecutable, isTrue);
        expect(fresh.hasCurrentRevisionConflict, isFalse);

        final stale = preview.planForExecution(actualCurrentRevisionId: 6);
        expect(stale.isExecutable, isFalse);
        expect(stale.hasCurrentRevisionConflict, isTrue);
        expect(stale.expectedCurrentRevisionId, 5);
        expect(stale.actualCurrentRevisionId, 6);
      },
    );

    test('cross-Object and non-historical revision planning fails closed', () {
      expect(
        () => planner.preview(
          historical: _checkpoint(objectId: 7, revisionId: 2),
          current: _checkpoint(objectId: 8, revisionId: 5),
          scope: ObjectHistoryRestoreScope.wholeObject(),
        ),
        throwsArgumentError,
      );
      expect(
        () => planner.preview(
          historical: _checkpoint(revisionId: 5),
          current: _checkpoint(revisionId: 5),
          scope: ObjectHistoryRestoreScope.wholeObject(),
        ),
        throwsArgumentError,
      );
    });
  });
}

ObjectHistoryCheckpointPayload _checkpoint({
  int objectId = 7,
  required int revisionId,
  String title = 'Same title',
  List<ObjectHistoryPropertySnapshot> properties =
      const <ObjectHistoryPropertySnapshot>[],
  List<int> relationPropertyIds = const <int>[],
  String bodyText = 'Same body',
}) => ObjectHistoryCheckpointPayload(
  entry: ObjectHistoryEntry(
    objectId: objectId,
    revisionId: revisionId,
    capturedAt: DateTime.utc(2026, 9, 11, 7, revisionId),
    source: ObjectHistorySourceKind.userMutation,
  ),
  title: title,
  propertySnapshots: properties,
  relationRequirements: relationPropertyIds
      .map(
        (propertyId) => ObjectHistoryRelationRequirement.fromDefinition(
          _property(id: propertyId, type: ObjectPropertyType.objectRelation),
        ),
      )
      .toList(growable: false),
  body: ObjectBodyDocument(
    blocks: <ObjectBodyBlock>[
      ObjectBodyBlock.paragraph(id: 'p1', text: bodyText),
    ],
  ),
);

ObjectHistoryPropertySnapshot _snapshot({
  required int id,
  required ObjectPropertyType type,
  required dynamic value,
}) => ObjectHistoryPropertySnapshot.fromDefinition(
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
