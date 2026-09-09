import '../domain/object_model.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';

/// Read-only in-memory view of one validated canonical Tag hierarchy.
///
/// The snapshot stores only direct Parent edges. Ancestors and descendants are
/// derived in memory so hierarchy queries do not introduce a second persistent
/// tree/closure store.
class TagHierarchySnapshot {
  TagHierarchySnapshot(Map<int, int?> parentByTagObjectId)
    : parentByTagObjectId = Map.unmodifiable(parentByTagObjectId);

  final Map<int, int?> parentByTagObjectId;

  bool isStrictDescendant(int descendantObjectId, int ancestorObjectId) {
    if (descendantObjectId == ancestorObjectId ||
        !parentByTagObjectId.containsKey(descendantObjectId) ||
        !parentByTagObjectId.containsKey(ancestorObjectId)) {
      return false;
    }

    var current = parentByTagObjectId[descendantObjectId];
    final visited = <int>{descendantObjectId};
    while (current != null) {
      if (!visited.add(current)) {
        throw StateError('Canonical Tag hierarchy snapshot contains a cycle.');
      }
      if (current == ancestorObjectId) return true;
      current = parentByTagObjectId[current];
    }
    return false;
  }
}

/// Integrity boundary for canonical Tag hierarchy mutations.
///
/// Tag hierarchy remains ordinary Object/Relation persistence. This service
/// adds only the Tag-specific meaning that the generic Relation subsystem
/// cannot infer: Parent must be a single Tag -> Tag edge and the resulting
/// parent chain must stay acyclic. Group membership is likewise a canonical
/// single Relation to a caller-provisioned TagGroup ObjectType.
///
/// Every mutation first reuses [RelationTargetService.selectionForMutation] so
/// malformed stored values, missing/wrong-type targets, cardinality violations,
/// and stored/index drift fail closed without repair. The final write still goes
/// through [RelationMutationService], preserving canonical edge/backlink/delete
/// behavior rather than introducing a parallel tree store.
class TagHierarchyIntegrityService {
  TagHierarchyIntegrityService({
    required this.objectStore,
    required this.relationMutations,
    RelationTargetService? relationTargets,
  }) : relationTargets = relationTargets ?? RelationTargetService(objectStore);

  final ObjectStore objectStore;
  final RelationMutationService relationMutations;
  final RelationTargetService relationTargets;

  /// Loads a transactionally consistent read-only snapshot from canonical
  /// Parent Relation state.
  ///
  /// Every Tag is checked through the same strict mutation preflight used by
  /// integrity-sensitive writes. Malformed values, missing/wrong-type targets,
  /// cardinality violations, stored/index drift, and an already persisted cycle
  /// therefore fail closed instead of being hidden from query/UI consumers.
  Future<TagHierarchySnapshot> loadSnapshot({
    required int workspaceId,
    required ObjectPropertyDefinition parentProperty,
  }) => relationMutations.genericStore.database.transaction(() async {
    final resolved = await _parentCandidates(
      workspaceId: workspaceId,
      parentProperty: parentProperty,
    );
    final parents = <int, int?>{};
    for (final tag in resolved.objects) {
      final context = await relationTargets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: tag.id,
        property: resolved.property,
      );
      final selected = context.selectedObjectIds;
      parents[tag.id] = selected.isEmpty ? null : selected.single;
    }
    _validateAcyclicSnapshot(parents);
    return TagHierarchySnapshot(parents);
  });

  Future<void> setParent({
    required int workspaceId,
    required int tagObjectId,
    required ObjectPropertyDefinition parentProperty,
    int? parentTagObjectId,
  }) => relationMutations.genericStore.database.transaction(() async {
    final resolved = await _parentCandidates(
      workspaceId: workspaceId,
      parentProperty: parentProperty,
    );
    final property = resolved.property;

    final tagIds = resolved.objects.map((object) => object.id).toSet();
    if (!tagIds.contains(tagObjectId)) {
      throw ArgumentError.value(
        tagObjectId,
        'tagObjectId',
        'Tag Object does not belong to the canonical Tag ObjectType.',
      );
    }
    if (parentTagObjectId != null && !tagIds.contains(parentTagObjectId)) {
      throw ArgumentError.value(
        parentTagObjectId,
        'parentTagObjectId',
        'Parent must be a canonical Tag Object in the same workspace.',
      );
    }
    if (parentTagObjectId == tagObjectId) {
      throw ArgumentError.value(
        parentTagObjectId,
        'parentTagObjectId',
        'A Tag cannot be its own parent.',
      );
    }

    // Validate the source's current Relation before replacing it. Explicit
    // user mutation must not opportunistically repair a malformed value or
    // stale normalized edge projection.
    await relationTargets.selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: tagObjectId,
      property: property,
    );

    // A null parent cannot introduce a cycle. For a non-null parent, walk
    // only the ancestor chain that would become reachable after this write.
    // Each hop is loaded through the strict canonical mutation preflight,
    // so corruption on the relevant path fails closed before any write.
    var current = parentTagObjectId;
    final visited = <int>{tagObjectId};
    while (current != null) {
      if (!visited.add(current)) {
        throw StateError('Tag Parent mutation would introduce a cycle.');
      }
      final context = await relationTargets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: current,
        property: property,
      );
      final selected = context.selectedObjectIds;
      current = selected.isEmpty ? null : selected.single;
    }

    await relationMutations.setRelation(
      objectId: tagObjectId,
      property: property,
      targetObjectIds: parentTagObjectId == null
          ? const <int>[]
          : <int>[parentTagObjectId],
    );
  });

  Future<void> setGroup({
    required int workspaceId,
    required int tagObjectId,
    required ObjectPropertyDefinition groupProperty,
    int? tagGroupObjectId,
  }) => relationMutations.genericStore.database.transaction(() async {
    final resolved = await relationTargets.candidatesFor(
      workspaceId: workspaceId,
      property: groupProperty,
    );
    final property = resolved.property;
    if (property.allowsMultipleRelations) {
      throw StateError('Tag Group membership must be a single Relation.');
    }

    await relationTargets.selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: tagObjectId,
      property: property,
    );

    if (tagGroupObjectId != null &&
        !resolved.objects.any((object) => object.id == tagGroupObjectId)) {
      throw ArgumentError.value(
        tagGroupObjectId,
        'tagGroupObjectId',
        'Group must be an Object of the Relation target TagGroup ObjectType.',
      );
    }

    await relationMutations.setRelation(
      objectId: tagObjectId,
      property: property,
      targetObjectIds: tagGroupObjectId == null
          ? const <int>[]
          : <int>[tagGroupObjectId],
    );
  });

  Future<RelationTargetCandidates> _parentCandidates({
    required int workspaceId,
    required ObjectPropertyDefinition parentProperty,
  }) async {
    final resolved = await relationTargets.candidatesFor(
      workspaceId: workspaceId,
      property: parentProperty,
    );
    final property = resolved.property;
    if (property.targetObjectTypeId != property.objectTypeId ||
        property.allowsMultipleRelations) {
      throw StateError(
        'Tag Parent must be a single Relation targeting the same Tag ObjectType.',
      );
    }
    return resolved;
  }

  void _validateAcyclicSnapshot(Map<int, int?> parents) {
    for (final start in parents.keys) {
      final visited = <int>{};
      int? current = start;
      while (current != null) {
        if (!parents.containsKey(current)) {
          throw StateError(
            'Canonical Tag hierarchy references a Tag outside the snapshot.',
          );
        }
        if (!visited.add(current)) {
          throw StateError('Canonical Tag hierarchy contains a cycle.');
        }
        current = parents[current];
      }
    }
  }
}
