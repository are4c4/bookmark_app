import '../data/generic_database_store.dart';
import '../data/object_store.dart';
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
        _resolver = ObjectSearchResultResolver(ObjectStore(genericStore));

  final ObjectSearchRepository _index;
  final ObjectSearchResultResolver _resolver;

  Future<void> rebuildWorkspace(int workspaceId) =>
      _index.rebuildWorkspace(workspaceId);

  Future<void> refreshObject(int objectId) => _index.refreshObject(objectId);

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
