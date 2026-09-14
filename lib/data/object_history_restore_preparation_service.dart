import '../domain/object_history_checkpoint.dart';
import '../domain/object_history_contract.dart';
import '../domain/object_history_relation.dart';
import '../domain/object_history_restore_composition.dart';
import '../domain/object_history_restore_planner.dart';
import 'object_history_checkpoint_loader.dart';
import 'object_history_relation_service.dart';

typedef ObjectHistoryWholeCheckpointLoad =
    Future<ObjectHistoryWholeCheckpoint?> Function({
      required int objectId,
      required int revisionId,
    });

typedef ObjectHistoryRelationRestorePreview =
    Future<ObjectHistoryRelationRestorePlan> Function({
      required int workspaceId,
      required ObjectHistoryRelationSnapshot historical,
      required Map<int, int> targetResolutions,
    });

/// Read-only preparation evidence for one durable history restore attempt.
///
/// This object combines A's checkpoint comparison with B-owned Relation restore
/// previews. It grants no mutation authority; execution still belongs to the
/// established A/B restore composition and canonical Relation service.
class ObjectHistoryRestorePreparation {
  ObjectHistoryRestorePreparation({
    required this.historical,
    required this.preview,
    required List<ObjectHistoryRelationRestorePlan> relationPlans,
  }) : relationPlans = List<ObjectHistoryRelationRestorePlan>.unmodifiable(
         relationPlans,
       );

  final ObjectHistoryWholeCheckpoint historical;
  final ObjectHistoryCheckpointRestorePreview preview;
  final List<ObjectHistoryRelationRestorePlan> relationPlans;

  bool get hasAOwnedBlockers => preview.hasAOwnedBlockers;

  bool get hasRelationBlockers =>
      relationPlans.any((plan) => !plan.isExecutable);

  bool get canCoordinate => !hasAOwnedBlockers && !hasRelationBlockers;
}

/// A-owned read composition boundary from persisted history to restore preview.
///
/// Historical Relation evidence stays immutable and B-owned. The service only
/// matches the Relation Properties requested by the A preview and delegates all
/// current-graph validation to [ObjectHistoryRelationService.previewRestore].
class ObjectHistoryRestorePreparationService {
  ObjectHistoryRestorePreparationService({
    required ObjectHistoryWholeCheckpointLoad loadHistorical,
    required ObjectHistoryRelationRestorePreview previewRelation,
    ObjectHistoryCheckpointRestorePlanner planner =
        const ObjectHistoryCheckpointRestorePlanner(),
  }) : _loadHistorical = loadHistorical,
       _previewRelation = previewRelation,
       _planner = planner;

  factory ObjectHistoryRestorePreparationService.fromServices({
    required ObjectHistoryCheckpointLoader checkpointLoader,
    required ObjectHistoryRelationService relationService,
  }) => ObjectHistoryRestorePreparationService(
    loadHistorical: checkpointLoader.load,
    previewRelation:
        ({
          required workspaceId,
          required historical,
          required targetResolutions,
        }) => relationService.previewRestore(
          workspaceId: workspaceId,
          historical: historical,
          targetResolutions: targetResolutions,
        ),
  );

  final ObjectHistoryWholeCheckpointLoad _loadHistorical;
  final ObjectHistoryRelationRestorePreview _previewRelation;
  final ObjectHistoryCheckpointRestorePlanner _planner;

  Future<ObjectHistoryRestorePreparation?> prepare({
    required int workspaceId,
    required int objectId,
    required int historicalRevisionId,
    required ObjectHistoryCheckpointPayload current,
    required ObjectHistoryRestoreScope scope,
    Map<int, Map<int, int>> relationTargetResolutions =
        const <int, Map<int, int>>{},
  }) async {
    if (workspaceId <= 0) {
      throw ArgumentError.value(
        workspaceId,
        'workspaceId',
        'workspaceId must be positive.',
      );
    }
    if (objectId <= 0) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'objectId must be positive.',
      );
    }
    if (historicalRevisionId <= 0) {
      throw ArgumentError.value(
        historicalRevisionId,
        'historicalRevisionId',
        'historicalRevisionId must be positive.',
      );
    }
    if (current.entry.objectId != objectId) {
      throw ArgumentError(
        'Current history checkpoint must belong to Object $objectId.',
      );
    }

    final historical = await _loadHistorical(
      objectId: objectId,
      revisionId: historicalRevisionId,
    );
    if (historical == null) return null;

    final preview = _planner.preview(
      historical: historical.checkpoint,
      current: current,
      scope: scope,
    );
    final requiredRelationPropertyIds = preview.requiredRelationPropertyIds;
    final snapshotsByProperty = <int, ObjectHistoryRelationSnapshot>{
      for (final snapshot in historical.relationSnapshots)
        snapshot.propertyId: snapshot,
    };
    final relationPlans = <ObjectHistoryRelationRestorePlan>[];

    for (final propertyId in requiredRelationPropertyIds) {
      final snapshot = snapshotsByProperty[propertyId];
      if (snapshot == null) {
        throw StateError(
          'Persisted whole-Object history is missing Relation Property '
          '$propertyId required by the restore preview.',
        );
      }
      relationPlans.add(
        await _previewRelation(
          workspaceId: workspaceId,
          historical: snapshot,
          targetResolutions:
              relationTargetResolutions[propertyId] ?? const <int, int>{},
        ),
      );
    }

    final unexpectedResolutionProperties =
        relationTargetResolutions.keys
            .where(
              (propertyId) => !requiredRelationPropertyIds.contains(propertyId),
            )
            .toList()
          ..sort();
    if (unexpectedResolutionProperties.isNotEmpty) {
      throw ArgumentError.value(
        relationTargetResolutions,
        'relationTargetResolutions',
        'Target resolutions were supplied for Relation Properties not requested '
            'by this restore scope: $unexpectedResolutionProperties.',
      );
    }

    return ObjectHistoryRestorePreparation(
      historical: historical,
      preview: preview,
      relationPlans: relationPlans,
    );
  }
}
