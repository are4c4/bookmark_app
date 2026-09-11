import '../domain/object_merge_contract.dart';
import '../domain/object_merge_state_materializer.dart';
import 'generic_database_store.dart';
import 'object_merge_state_store.dart';
import 'object_redirect_store.dart';
import 'object_store.dart';
import 'relation_object_merge_service.dart';

class ObjectMergeFinalizationResult {
  const ObjectMergeFinalizationResult({
    required this.survivingObjectId,
    required this.alreadyFinalized,
    this.relationImpact,
  });

  final int survivingObjectId;
  final bool alreadyFinalized;
  final RelationObjectMergeImpact? relationImpact;
}

/// A-owned coordinator for the final persistent phase of explicit Object merge.
///
/// Relation planning and rewiring stay delegated to [RelationObjectMergeService].
/// This service only sequences the already-established A/B boundaries inside one
/// outer transaction: stale-state validation, canonical Relation rewiring,
/// resolved A-owned state persistence, durable redirect creation, then retired
/// Object deletion.
class ObjectMergeFinalizer {
  ObjectMergeFinalizer({
    required this.genericStore,
    required this.stateStore,
    required this.relationMergeService,
    required this.redirectStore,
    required this.objectStore,
    ObjectMergeStateMaterializer materializer =
        const ObjectMergeStateMaterializer(),
  }) : _materializer = materializer;

  final GenericDatabaseStore genericStore;
  final ObjectMergeStateStore stateStore;
  final RelationObjectMergeService relationMergeService;
  final ObjectRedirectStore redirectStore;
  final ObjectStore objectStore;
  final ObjectMergeStateMaterializer _materializer;

  Future<ObjectMergeFinalizationResult> finalize({
    required int workspaceId,
    required ObjectMergePreparedState prepared,
    required ObjectMergePlan plan,
  }) async {
    final nextSurvivor = _materializer.materialize(
      prepared: prepared,
      plan: plan,
    );
    final survivorObjectId = prepared.survivor.objectId;
    final retiredObjectId = prepared.retired.objectId;
    final objectTypeId = prepared.survivor.objectTypeId;

    if (prepared.retired.objectTypeId != objectTypeId) {
      throw StateError(
        'Object merge finalization requires survivor and retired Objects to share one ObjectType.',
      );
    }

    // The redirect table is an already-established durable A boundary. Prepare
    // it before beginning the user-data transaction so schema bootstrap is not
    // interleaved with the merge mutation sequence.
    await redirectStore.ensureSchema();

    return genericStore.database.transaction(() async {
      final redirected = await redirectStore.resolve(retiredObjectId);
      if (redirected != retiredObjectId) {
        final retiredStillExists = await _objectExists(
          objectTypeId: objectTypeId,
          objectId: retiredObjectId,
        );
        if (retiredStillExists) {
          throw StateError(
            'Object merge redirect exists while the retired Object row is still present.',
          );
        }
        return ObjectMergeFinalizationResult(
          survivingObjectId: redirected,
          alreadyFinalized: true,
        );
      }

      final resolvedSurvivor = await redirectStore.resolve(survivorObjectId);
      if (resolvedSurvivor != survivorObjectId) {
        throw StateError(
          'Object merge survivor is already retired through a redirect chain.',
        );
      }

      final survivorUnchanged = await stateStore.matchesCurrent(
        prepared.survivor,
      );
      final retiredUnchanged = await stateStore.matchesCurrent(prepared.retired);
      if (!survivorUnchanged || !retiredUnchanged) {
        throw StateError(
          'Object merge prepared A-owned state is stale; prepare the merge again before finalizing.',
        );
      }

      final relationPlan = await relationMergeService.preview(
        workspaceId: workspaceId,
        objectTypeId: objectTypeId,
        survivorObjectId: survivorObjectId,
        retiredObjectId: retiredObjectId,
      );
      if (!relationPlan.isExecutable) {
        throw StateError(
          'Object merge Relation state is no longer executable; preview the merge again.',
        );
      }

      final relationImpact = await relationMergeService.apply(relationPlan);

      final persisted = await stateStore.writeIfUnchanged(
        expected: prepared.survivor,
        next: nextSurvivor,
      );
      if (!persisted) {
        throw StateError(
          'Object merge survivor state changed during finalization.',
        );
      }

      await redirectStore.recordRedirect(
        retiredObjectId: retiredObjectId,
        survivorObjectId: survivorObjectId,
      );
      await objectStore.deleteObject(retiredObjectId);

      if (await _objectExists(
        objectTypeId: objectTypeId,
        objectId: retiredObjectId,
      )) {
        throw StateError(
          'Retired Object row still exists after merge finalization.',
        );
      }
      final resolved = await redirectStore.resolve(retiredObjectId);
      if (resolved != survivorObjectId) {
        throw StateError(
          'Object merge redirect did not resolve to the surviving Object after retirement.',
        );
      }

      return ObjectMergeFinalizationResult(
        survivingObjectId: survivorObjectId,
        alreadyFinalized: false,
        relationImpact: relationImpact,
      );
    });
  }

  Future<bool> _objectExists({
    required int objectTypeId,
    required int objectId,
  }) async =>
      (await objectStore.listObjects(objectTypeId)).any(
        (object) => object.id == objectId,
      );
}
