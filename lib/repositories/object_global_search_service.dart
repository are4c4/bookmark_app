import 'dart:async';

import '../data/generic_database_store.dart';
import '../data/object_graph_query_store.dart';
import '../data/object_store.dart';
import '../services/canonical_file_pdf_search_indexer.dart';
import 'object_search_refresh_planner.dart';
import 'object_search_repository.dart';
import 'object_search_result_resolver.dart';

final Expando<_ObjectSearchProjectionChangeChannel>
    _objectSearchProjectionChangeChannels =
    Expando<_ObjectSearchProjectionChangeChannel>(
      'object-search-projection-changes',
    );

_ObjectSearchProjectionChangeChannel _projectionChangesFor(
  GenericDatabaseStore genericStore,
) {
  final database = genericStore.database;
  return _objectSearchProjectionChangeChannels[database] ??=
      _ObjectSearchProjectionChangeChannel();
}

class _ObjectSearchProjectionChangeChannel {
  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() => _controller.add(null);
}

/// Canonical application-facing search boundary for global Object search.
///
/// UI callers do not need to know about the FTS virtual table or manually
/// re-resolve ids. Search always returns current canonical Objects/ObjectTypes,
/// while stale index identities fail closed in [ObjectSearchResultResolver].
class ObjectGlobalSearchService {
  ObjectGlobalSearchService(
    GenericDatabaseStore genericStore, {
    CanonicalFilePdfSearchIndexer? pdfSearchIndexer,
  })  : _projectionChanges = _projectionChangesFor(genericStore),
        _index = ObjectSearchRepository(genericStore),
        _resolver = ObjectSearchResultResolver(ObjectStore(genericStore)),
        _refreshPlanner = ObjectSearchRefreshPlanner(ObjectStore(genericStore)),
        _graphStore = ObjectGraphQueryStore(genericStore),
        _pdfSearchIndexer =
            pdfSearchIndexer ?? CanonicalFilePdfSearchIndexer.forStore(genericStore);

  final _ObjectSearchProjectionChangeChannel _projectionChanges;
  final ObjectSearchRepository _index;
  final ObjectSearchResultResolver _resolver;
  final ObjectSearchRefreshPlanner _refreshPlanner;
  final ObjectGraphQueryStore _graphStore;
  final CanonicalFilePdfSearchIndexer _pdfSearchIndexer;

  /// Search-local notification emitted after a successful focused projection
  /// refresh. Separate service instances backed by the same AppDatabase share
  /// this stream, allowing a mounted Search page to replay its active query
  /// after background producers update FTS through another service instance.
  ///
  /// This is intentionally not a domain/workspace mutation event bus: Object,
  /// Relation and Primitive producers remain unaware of Search presentation and
  /// report only canonical ids to Search-owned refresh methods.
  Stream<void> get projectionChanges => _projectionChanges.stream;

  /// Rebuilds canonical Object search for one workspace after reconciling the
  /// optional PDF-derived contribution of canonical File Objects.
  Future<void> rebuildWorkspace(int workspaceId) =>
      _pdfSearchIndexer.rebuildWorkspace(workspaceId);

  Future<void> refreshObject(int objectId) => refreshObjects(<int>[objectId]);

  /// Re-extracts and reindexes one canonical File's optional PDF text without
  /// rebuilding unrelated Objects.
  Future<bool> refreshFilePdfText({
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    final available = await _pdfSearchIndexer.refresh(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );
    _projectionChanges.notify();
    return available;
  }

  /// Refreshes a deterministic set of canonical Object ids without rebuilding
  /// unrelated workspace rows.
  Future<void> refreshObjects(Iterable<int> objectIds) async {
    final ordered = objectIds.toSet().toList()..sort();
    if (ordered.isEmpty) return;
    for (final objectId in ordered) {
      await _index.refreshObject(objectId);
    }
    _projectionChanges.notify();
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

  /// Refreshes multiple canonical mutation roots plus their current Relation
  /// label dependents in one deterministic focused pass.
  ///
  /// Live compatibility mirrors can update several canonical Objects at once
  /// (for example Bookmark + reusable Weblink). The producer reports only ids;
  /// Search owns expanding those roots through its existing invalidation
  /// planner and de-duplicating the resulting projections.
  Future<void> refreshObjectLabelDependentsFor(
    Iterable<int> objectIds,
  ) async {
    final roots = objectIds.toSet().toList()..sort();
    final affected = <int>{};
    for (final objectId in roots) {
      affected.addAll(await _refreshPlanner.forObjectLabelChange(objectId));
    }
    await refreshObjects(affected);
  }

  /// Refreshes the focused set of projections that a Search-opened detail may
  /// have affected: the opened Object, its label dependents, trustworthy current
  /// outgoing Relation targets, and each target's label dependents.
  Future<void> refreshDetailReturnAffected({
    required int objectTypeId,
    required int objectId,
  }) async {
    await refreshObjects(
      await _refreshPlanner.forDetailReturn(
        objectTypeId: objectTypeId,
        objectId: objectId,
      ),
    );
  }

  /// Refreshes every canonical Object visited while one Search-opened detail
  /// route was active, plus the existing focused Relation-dependent expansion
  /// for each visited Object.
  ///
  /// Nested Object Inspector navigation is not always Relation-backed (Daily
  /// Note previous/next/today navigation is the canonical example). Resolve the
  /// current ObjectType from canonical graph identity, then reuse the same
  /// focused detail-return planner for every visited Object. Missing/deleted
  /// Objects still refresh their own id so stale FTS rows are removed.
  Future<void> refreshVisitedDetailReturnObjects(
    Iterable<int> objectIds,
  ) async {
    final roots = objectIds.toSet().toList()..sort();
    final affected = <int>{};
    for (final objectId in roots) {
      final node = await _graphStore.getNode(objectId);
      if (node == null) {
        affected.add(objectId);
        continue;
      }
      affected.addAll(
        await _refreshPlanner.forDetailReturn(
          objectTypeId: node.objectTypeId,
          objectId: objectId,
        ),
      );
    }
    await refreshObjects(affected);
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
