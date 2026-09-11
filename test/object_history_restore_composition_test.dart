import 'package:flutter_test/flutter_test.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:bookmark_app/domain/object_history_relation.dart';
import 'package:bookmark_app/domain/object_history_restore_composition.dart';
import 'package:bookmark_app/domain/object_history_restore_planner.dart';

void main() {
  group('ObjectHistoryRestoreComposition', () {
    test('exposes requested Relation Property ids in deterministic order', () {
      final preview = _preview(relationPropertyIds: <int>[22, 11]);

      expect(preview.requiredRelationPropertyIds, <int>[11, 22]);
    });

    test('coordinates matching executable B plans', () {
      final preview = _preview(relationPropertyIds: <int>[11, 22]);

      final coordinated = preview.coordinateWithRelations(
        actualCurrentRevisionId: 5,
        relationPlans: <ObjectHistoryRelationRestorePlan>[
          _relationPlan(propertyId: 22, changedObjectIds: <int>[9, 1]),
          _relationPlan(propertyId: 11, changedObjectIds: <int>[1, 7]),
        ],
      );

      expect(coordinated.isExecutable, isTrue);
      expect(
        coordinated.relationPlans
            .map((plan) => plan.historical.propertyId)
            .toList(),
        <int>[11, 22],
      );
      expect(coordinated.changedRelationObjectIds, <int>[1, 7, 9]);
      expect(coordinated.corePlan.relationBlockers, isEmpty);
    });

    test('fails closed when a requested Relation plan is missing', () {
      final preview = _preview(relationPropertyIds: <int>[11, 22]);

      expect(
        () => preview.coordinateWithRelations(
          actualCurrentRevisionId: 5,
          relationPlans: <ObjectHistoryRelationRestorePlan>[
            _relationPlan(propertyId: 11),
          ],
        ),
        throwsStateError,
      );
    });

    test('fails closed for duplicate, unrequested, or wrong-source plans', () {
      final preview = _preview(relationPropertyIds: <int>[11]);

      expect(
        () => preview.coordinateWithRelations(
          actualCurrentRevisionId: 5,
          relationPlans: <ObjectHistoryRelationRestorePlan>[
            _relationPlan(propertyId: 11),
            _relationPlan(propertyId: 11),
          ],
        ),
        throwsStateError,
      );
      expect(
        () => preview.coordinateWithRelations(
          actualCurrentRevisionId: 5,
          relationPlans: <ObjectHistoryRelationRestorePlan>[
            _relationPlan(propertyId: 12),
          ],
        ),
        throwsStateError,
      );
      expect(
        () => preview.coordinateWithRelations(
          actualCurrentRevisionId: 5,
          relationPlans: <ObjectHistoryRelationRestorePlan>[
            _relationPlan(propertyId: 11, sourceObjectId: 2),
          ],
        ),
        throwsStateError,
      );
    });

    test('fails closed for blocked B plan or stale A revision', () {
      final preview = _preview(relationPropertyIds: <int>[11]);

      expect(
        () => preview.coordinateWithRelations(
          actualCurrentRevisionId: 5,
          relationPlans: <ObjectHistoryRelationRestorePlan>[
            _relationPlan(propertyId: 11, blocked: true),
          ],
        ),
        throwsStateError,
      );
      expect(
        () => preview.coordinateWithRelations(
          actualCurrentRevisionId: 6,
          relationPlans: <ObjectHistoryRelationRestorePlan>[
            _relationPlan(propertyId: 11),
          ],
        ),
        throwsStateError,
      );
    });
  });
}

ObjectHistoryCheckpointRestorePreview _preview({
  required List<int> relationPropertyIds,
}) => ObjectHistoryCheckpointRestorePreview(
  objectId: 1,
  historicalRevisionId: 3,
  preparedCurrentRevisionId: 5,
  scope: ObjectHistoryRestoreScope.wholeObject(),
  decisions: const <ObjectHistoryRestoreFieldDecision>[],
  relationBlockers: <ObjectHistoryRelationBlocker>[
    for (final propertyId in relationPropertyIds)
      ObjectHistoryRelationBlocker(
        key: 'property:$propertyId',
        reason: 'Requires canonical B-owned restore validation.',
      ),
  ],
);

ObjectHistoryRelationRestorePlan _relationPlan({
  required int propertyId,
  int sourceObjectId = 1,
  List<int> changedObjectIds = const <int>[],
  bool blocked = false,
}) => ObjectHistoryRelationRestorePlan(
  workspaceId: 1,
  historical: ObjectHistoryRelationSnapshot(
    sourceObjectId: sourceObjectId,
    sourceObjectTypeId: 10,
    propertyId: propertyId,
    targetObjectTypeId: 20,
    allowsMultipleRelations: true,
    targetObjectIds: const <int>[30],
  ),
  beforeTargetObjectIds: const <int>[],
  targetResolutions: const <ObjectHistoryRelationTargetResolution>[
    ObjectHistoryRelationTargetResolution(
      historicalTargetObjectId: 30,
      currentTargetObjectId: 30,
    ),
  ],
  blockers: blocked
      ? <ObjectHistoryRelationBlocker>[
          ObjectHistoryRelationBlocker(
            key: 'property:$propertyId:blocked',
            reason: 'Blocked for test.',
          ),
        ]
      : const <ObjectHistoryRelationBlocker>[],
  changedObjectIds: changedObjectIds,
);
