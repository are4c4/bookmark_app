import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import 'object_search_refresh_planner.dart';
import 'object_search_repository.dart';
import 'object_search_result_resolver.dart';

/// Canonical application-facing search boundary for global Object search.
///
/// UI callers do not need to know about the FTS virtual table or manually
/// re-resolve ids. Search always returns current canonical Objects/ObjectTypes,
/// while stale index identities fail closed in [ObjectSearchResultResolver].
class ObjectGlobalSearchService {
  ObjectGlobalSearchService(GenericDatabaseStore genericStore)
      : _index = ObjectSearchRepository(genericStore),
        _resolver = ObjectSearchResultResolver(ObjectStore(genericStore)),
        _refreshPlanner = ObjectSearchRefreshPlanner(ObjectStore(genericStore));

  final ObjectSearchRepository _index;
  final ObjectSearchResultResolver _resolver;
  final ObjectSearchRefreshPlanner _refreshPlanner;

  Future<void> rebuildWorkspace(int workspaceId) =>
      _index.rebuildWorkspace(workspaceId);

  Future<void> refreshObject(int objectId) => _index.refreshObject(objectId);

  /// Refreshes a deterministic set of canonical Object ids without rebuilding
  /// unrelated workspace rows.
  Future<void> refreshObjects(Iterable<int> objectIds) async {
    final ordered = objectIds.toSet().toList()..sort();
    for (final objectId in ordered) {
      await _index.refreshObject(objectId);
    }
  }

  /// Refreshes an Object whose display label changed plus every source Object
  /// currently denormalizing that label through a Relation.
  ///
  /// This is intended for rename/update flows while Relation edges still
  /// exist. Destructive deletion flows must collect dependent ids before the
  /// Object is deleted because canonical Relation edges cascade on deletion.
  Future<void> refreshObjectLabelDependents(int objectId) async {
    await refreshObjects(await _refreshPlanner.forObjectLabelChange(objectId));
  }

  Future<List<ResolvedObjectSearchHit>> search({
    required int workspaceId,
    required String rawQuery,
    int? objectTypeId,
    int limit = 100,
  }) async {
    final hits = await _index.search(
      workspaceId: workspaceId,
      rawQuery: rawQuery,
      objectTypeId: objectTypeId,
      limit: limit,
    );
    return _resolver.resolve(hits);
  }
}
