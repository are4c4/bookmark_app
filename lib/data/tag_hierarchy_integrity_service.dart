import '../domain/object_model.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';

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

  Future<void> setParent({
    required int workspaceId,
    required int tagObjectId,
    required ObjectPropertyDefinition parentProperty,
    int? parentTagObjectId,
  }) =>
      relationMutations.genericStore.database.transaction(() async {
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
  }) =>
      relationMutations.genericStore.database.transaction(() async {
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
}
