import 'package:bookmark_app/data/object_history_checkpoint_loader.dart';
import 'package:bookmark_app/data/object_history_restore_preparation_service.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_history_checkpoint.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:bookmark_app/domain/object_history_relation.dart';
import 'package:bookmark_app/domain/object_history_restore_composition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObjectHistoryRestorePreparationService', () {
    test(
      'prepares requested persisted Relation evidence through B preview',
      () async {
        final historical = _checkpoint(revisionId: 2, title: 'Earlier');
        final current = _checkpoint(revisionId: 3, title: 'Current');
        final snapshot = _relationSnapshot();
        final calls = <ObjectHistoryRelationSnapshot>[];
        final resolutions = <Map<int, int>>[];
        final service = ObjectHistoryRestorePreparationService(
          loadHistorical: ({required objectId, required revisionId}) async =>
              ObjectHistoryWholeCheckpoint(
                checkpoint: historical,
                relationSnapshots: <ObjectHistoryRelationSnapshot>[snapshot],
              ),
          previewRelation:
              ({
                required workspaceId,
                required historical,
                required targetResolutions,
              }) async {
                calls.add(historical);
                resolutions.add(targetResolutions);
                return _relationPlan(historical);
              },
        );

        final result = await service.prepare(
          workspaceId: 1,
          objectId: 7,
          historicalRevisionId: 2,
          current: current,
          scope: ObjectHistoryRestoreScope.wholeObject(),
          relationTargetResolutions: const <int, Map<int, int>>{
            13: <int, int>{30: 31},
          },
        );

        expect(result, isNotNull);
        expect(result!.historical.checkpoint.entry.revisionId, 2);
        expect(result.preview.requiredRelationPropertyIds, <int>[13]);
        expect(calls, <ObjectHistoryRelationSnapshot>[snapshot]);
        expect(resolutions, <Map<int, int>>[
          <int, int>{30: 31},
        ]);
        expect(result.canCoordinate, isTrue);
      },
    );

    test('selective non-Relation restore does not invoke B preview', () async {
      var relationPreviewCount = 0;
      final service = ObjectHistoryRestorePreparationService(
        loadHistorical: ({required objectId, required revisionId}) async =>
            ObjectHistoryWholeCheckpoint(
              checkpoint: _checkpoint(revisionId: 2, title: 'Earlier'),
              relationSnapshots: <ObjectHistoryRelationSnapshot>[
                _relationSnapshot(),
              ],
            ),
        previewRelation:
            ({
              required workspaceId,
              required historical,
              required targetResolutions,
            }) async {
              relationPreviewCount += 1;
              return _relationPlan(historical);
            },
      );

      final result = await service.prepare(
        workspaceId: 1,
        objectId: 7,
        historicalRevisionId: 2,
        current: _checkpoint(revisionId: 3, title: 'Current'),
        scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
          ObjectHistoryFieldTarget.title(),
        ]),
      );

      expect(result, isNotNull);
      expect(result!.preview.requiredRelationPropertyIds, isEmpty);
      expect(result.relationPlans, isEmpty);
      expect(relationPreviewCount, 0);
    });

    test('preserves A-owned blockers from the restore planner', () async {
      final historical = _checkpoint(
        revisionId: 2,
        title: 'Earlier',
        valueProperty: _valuePropertySnapshot('historical'),
      );
      final service = ObjectHistoryRestorePreparationService(
        loadHistorical: ({required objectId, required revisionId}) async =>
            ObjectHistoryWholeCheckpoint(
              checkpoint: historical,
              relationSnapshots: const <ObjectHistoryRelationSnapshot>[],
            ),
        previewRelation: ({
          required workspaceId,
          required historical,
          required targetResolutions,
        }) async => _relationPlan(historical),
      );

      final result = await service.prepare(
        workspaceId: 1,
        objectId: 7,
        historicalRevisionId: 2,
        current: _checkpoint(revisionId: 3, title: 'Current'),
        scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
          ObjectHistoryFieldTarget.property(14),
        ]),
      );

      expect(result, isNotNull);
      expect(result!.hasAOwnedBlockers, isTrue);
      expect(result.canCoordinate, isFalse);
      expect(result.preview.blockers, hasLength(1));
      expect(result.preview.blockers.single.key, 'property:14');
    });

    test(
      'returns null when the persisted historical revision is absent',
      () async {
        final service = ObjectHistoryRestorePreparationService(
          loadHistorical: ({required objectId, required revisionId}) async =>
              null,
          previewRelation: ({
            required workspaceId,
            required historical,
            required targetResolutions,
          }) async => _relationPlan(historical),
        );

        expect(
          await service.prepare(
            workspaceId: 1,
            objectId: 7,
            historicalRevisionId: 2,
            current: _checkpoint(revisionId: 3, title: 'Current'),
            scope: ObjectHistoryRestoreScope.wholeObject(),
          ),
          isNull,
        );
      },
    );
  });
}

ObjectHistoryCheckpointPayload _checkpoint({
  required int revisionId,
  required String title,
  ObjectHistoryPropertySnapshot? valueProperty,
}) => ObjectHistoryCheckpointPayload(
  entry: ObjectHistoryEntry(
    objectId: 7,
    revisionId: revisionId,
    previousRevisionId: revisionId > 1 ? revisionId - 1 : null,
    capturedAt: DateTime.utc(2026, 9, 14, revisionId),
    source: ObjectHistorySourceKind.userMutation,
  ),
  title: title,
  propertySnapshots: <ObjectHistoryPropertySnapshot>[
    if (valueProperty != null) valueProperty,
  ],
  body: const ObjectBodyDocument(),
  relationRequirements: <ObjectHistoryRelationRequirement>[
    ObjectHistoryRelationRequirement.fromDefinition(
      ObjectPropertyDefinition(
        id: 13,
        objectTypeId: 10,
        name: 'People',
        type: ObjectPropertyType.objectRelation,
        sortOrder: 0,
        config: const <String, dynamic>{
          'targetObjectTypeId': 20,
          'multiple': true,
        },
      ),
    ),
  ],
);

ObjectHistoryPropertySnapshot _valuePropertySnapshot(String value) =>
    ObjectHistoryPropertySnapshot.fromDefinition(
      property: ObjectPropertyDefinition(
        id: 14,
        objectTypeId: 10,
        name: 'Note',
        type: ObjectPropertyType.text,
        sortOrder: 1,
      ),
      value: value,
    );

ObjectHistoryRelationSnapshot _relationSnapshot() =>
    ObjectHistoryRelationSnapshot(
      sourceObjectId: 7,
      sourceObjectTypeId: 10,
      propertyId: 13,
      targetObjectTypeId: 20,
      allowsMultipleRelations: true,
      targetObjectIds: const <int>[30],
    );

ObjectHistoryRelationRestorePlan _relationPlan(
  ObjectHistoryRelationSnapshot historical,
) => ObjectHistoryRelationRestorePlan(
  workspaceId: 1,
  historical: historical,
  beforeTargetObjectIds: const <int>[],
  targetResolutions: <ObjectHistoryRelationTargetResolution>[
    for (final targetId in historical.targetObjectIds)
      ObjectHistoryRelationTargetResolution(
        historicalTargetObjectId: targetId,
        currentTargetObjectId: targetId,
      ),
  ],
  blockers: const <ObjectHistoryRelationBlocker>[],
  changedObjectIds: const <int>[7],
);
