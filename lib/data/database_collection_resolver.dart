import '../domain/database_collection_definition.dart';
import '../domain/object_model.dart';
import '../domain/object_query.dart';
import 'database_collection_store.dart';
import 'object_query_engine.dart';
import 'object_store.dart';
import 'tag_hierarchy_query_context_service.dart';

class ResolvedDatabaseCollection {
  const ResolvedDatabaseCollection({
    required this.definition,
    required this.objectType,
    required this.objects,
  });

  final DatabaseCollectionDefinition definition;
  final AppObjectType objectType;
  final List<AppObject> objects;
}

/// Resolves Database membership before any View-level query is applied.
///
/// This is the Phase-1 boundary between `Database = which Objects` and
/// `View = how to present/narrow them`. Callers can feed [objects] into the
/// existing View projector afterwards without merging the two filter layers.
class DatabaseCollectionResolver {
  const DatabaseCollectionResolver({
    required this.collectionStore,
    required this.objectStore,
    this.queryEngine = const ObjectQueryEngine(),
    this.tagHierarchyQueries,
  });

  final DatabaseCollectionStore collectionStore;
  final ObjectStore objectStore;
  final ObjectQueryEngine queryEngine;
  final TagHierarchyQueryContextService? tagHierarchyQueries;

  Future<ResolvedDatabaseCollection?> resolve(int databaseId) async {
    final definition = await collectionStore.readEffective(databaseId);
    if (definition == null) return null;

    final objectType = await objectStore.getObjectType(
      definition.targetObjectTypeId,
    );
    if (objectType == null || objectType.workspaceId != definition.workspaceId) {
      throw StateError(
        'Database collection target disappeared or crossed workspace boundaries.',
      );
    }

    ObjectHierarchyDescendantMatcher? hierarchyDescendantMatcher;
    final needsHierarchy = definition.collectionFilter.any(
      (rule) => rule.hierarchyMatchMode != ObjectHierarchyMatchMode.exact,
    );
    if (needsHierarchy) {
      final hierarchyContext =
          await (tagHierarchyQueries ??
                  TagHierarchyQueryContextService.fromStores(
                    genericStore: collectionStore.genericStore,
                    objectStore: objectStore,
                  ))
              .loadForObjectType(
        workspaceId: definition.workspaceId,
        objectType: objectType,
      );
      hierarchyDescendantMatcher = hierarchyContext.descendantMatcher;
    }

    final candidates = await objectStore.listObjects(objectType.id);
    final objects = queryEngine.apply(
      objects: candidates,
      filters: definition.collectionFilter,
      hierarchyDescendantMatcher: hierarchyDescendantMatcher,
    );
    return ResolvedDatabaseCollection(
      definition: definition,
      objectType: objectType,
      objects: List<AppObject>.unmodifiable(objects),
    );
  }
}
