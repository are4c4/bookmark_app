import '../domain/object_merge_state_materializer.dart';
import 'object_merge_state_store.dart';
import 'relation_object_merge_service.dart';

/// Read-only preparation result for one explicit Object merge candidate pair.
///
/// [prepared] owns the frozen A-side Object state and its merge requirements.
/// [relationPlan] is the canonical B-owned Relation preview for the exact same
/// survivor/retired identities. Neither value authorizes mutation by itself.
class ObjectMergePreparation {
  const ObjectMergePreparation({
    required this.prepared,
    required this.relationPlan,
  });

  final ObjectMergePreparedState prepared;
  final RelationObjectMergePlan relationPlan;
}

/// A-owned composition boundary that prepares an explicit Object merge without
/// mutating canonical state.
///
/// A-owned title/value-Property/Body/alias state is captured through
/// [ObjectMergeStateStore]. Relation integrity and rewiring feasibility remain
/// delegated to [RelationObjectMergeService]. The resulting B blockers are fed
/// into the existing A prepared-state contract so later UI cannot accidentally
/// treat an integrity-blocked merge as executable.
class ObjectMergePreparationService {
  const ObjectMergePreparationService({
    required this.stateStore,
    required this.relationMergeService,
  });

  final ObjectMergeStateStore stateStore;
  final RelationObjectMergeService relationMergeService;

  Future<ObjectMergePreparation> prepare({
    required int workspaceId,
    required int objectTypeId,
    required int survivorObjectId,
    required int retiredObjectId,
  }) async {
    final survivor = await stateStore.capture(
      objectTypeId: objectTypeId,
      objectId: survivorObjectId,
    );
    final retired = await stateStore.capture(
      objectTypeId: objectTypeId,
      objectId: retiredObjectId,
    );

    final relationPlan = await relationMergeService.preview(
      workspaceId: workspaceId,
      objectTypeId: objectTypeId,
      survivorObjectId: survivorObjectId,
      retiredObjectId: retiredObjectId,
    );

    final prepared = ObjectMergePreparedState.prepare(
      survivor: survivor,
      retired: retired,
      relationBlockers: relationPlan.relationBlockers,
    );

    return ObjectMergePreparation(
      prepared: prepared,
      relationPlan: relationPlan,
    );
  }
}
