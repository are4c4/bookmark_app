import '../domain/object_model.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_query_engine.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';
import 'system_object_store.dart';
import 'tag_hierarchy_integrity_service.dart';
import 'tag_object_bridge.dart';

/// Runtime-only hierarchy capability available to Database/View query layers.
///
/// The direct Tag assignments remain the only persisted values. The matcher is
/// backed by B's validated canonical Parent snapshot and is never serialized as
/// an ancestor list or closure cache.
class TagHierarchyQueryContext {
  const TagHierarchyQueryContext({
    this.hierarchyAwarePropertyIds = const <int>{},
    this.descendantMatcher,
  });

  static const unavailable = TagHierarchyQueryContext();

  final Set<int> hierarchyAwarePropertyIds;
  final ObjectHierarchyDescendantMatcher? descendantMatcher;
}

/// Adapts B's canonical Tag hierarchy reader to C's generic query surfaces.
class TagHierarchyQueryContextService {
  TagHierarchyQueryContextService({
    required this.systemObjects,
    required this.hierarchyIntegrity,
  });

  factory TagHierarchyQueryContextService.fromStores({
    required GenericDatabaseStore genericStore,
    required ObjectStore objectStore,
  }) {
    final systemObjects = SystemObjectStore(
      database: genericStore.database,
      objectStore: objectStore,
    );
    final relationMutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
    );
    return TagHierarchyQueryContextService(
      systemObjects: systemObjects,
      hierarchyIntegrity: TagHierarchyIntegrityService(
        objectStore: objectStore,
        relationMutations: relationMutations,
      ),
    );
  }

  final SystemObjectStore systemObjects;
  final TagHierarchyIntegrityService hierarchyIntegrity;

  Future<TagHierarchyQueryContext> loadForObjectType({
    required int workspaceId,
    required AppObjectType objectType,
  }) async {
    if (objectType.workspaceId != workspaceId) {
      return TagHierarchyQueryContext.unavailable;
    }

    final tagType = await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
    );
    if (tagType == null) return TagHierarchyQueryContext.unavailable;

    final hierarchyAwarePropertyIds = objectType.properties
        .where(
          (property) =>
              property.isRelation && property.targetObjectTypeId == tagType.id,
        )
        .map((property) => property.id)
        .toSet();
    if (hierarchyAwarePropertyIds.isEmpty) {
      return TagHierarchyQueryContext.unavailable;
    }

    final parentProperties = tagType.properties
        .where(
          (property) =>
              property.name == 'Parent' &&
              property.isRelation &&
              property.targetObjectTypeId == tagType.id &&
              !property.allowsMultipleRelations,
        )
        .toList(growable: false);
    if (parentProperties.length != 1) {
      return TagHierarchyQueryContext.unavailable;
    }

    try {
      final snapshot = await hierarchyIntegrity.loadSnapshot(
        workspaceId: workspaceId,
        parentProperty: parentProperties.single,
      );
      return TagHierarchyQueryContext(
        hierarchyAwarePropertyIds: Set<int>.unmodifiable(
          hierarchyAwarePropertyIds,
        ),
        descendantMatcher: snapshot.isStrictDescendant,
      );
    } catch (_) {
      // A damaged canonical Parent graph must not be guessed or repaired by the
      // query layer. Hiding hierarchy controls and supplying no matcher makes
      // existing non-exact predicates fail closed in ObjectQueryEngine while
      // ordinary exact filters remain usable.
      return TagHierarchyQueryContext.unavailable;
    }
  }
}
