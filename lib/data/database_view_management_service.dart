import 'database_view_store.dart';

/// Object-lane facade for safe View rename/reorder/delete operations.
///
/// The low-level store exposes id-based mutations for legacy callers. This
/// service keeps user-facing multi-View operations scoped to one
/// workspace/Database and rejects stale or cross-scope View payloads before a
/// write reaches storage.
class DatabaseViewManagementService {
  const DatabaseViewManagementService(this.store);

  final DatabaseViewStore store;

  Future<DatabaseViewConfig> rename(
    DatabaseViewConfig view,
    String name,
  ) async {
    final canonical = await _requireCurrent(view);
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'View name cannot be empty.');
    }
    await store.renameView(canonical.id, normalized);
    return _find(
      workspaceId: canonical.workspaceId,
      databaseKey: canonical.databaseKey,
      id: canonical.id,
    );
  }

  Future<List<DatabaseViewConfig>> reorder({
    required int workspaceId,
    required String databaseKey,
    required List<int> orderedViewIds,
  }) async {
    final current = await store.listViews(
      workspaceId: workspaceId,
      databaseKey: databaseKey,
    );
    final currentIds = current.map((view) => view.id).toSet();
    final requestedIds = orderedViewIds.toSet();
    if (orderedViewIds.length != current.length ||
        requestedIds.length != orderedViewIds.length ||
        !requestedIds.containsAll(currentIds) ||
        !currentIds.containsAll(requestedIds)) {
      throw ArgumentError.value(
        orderedViewIds,
        'orderedViewIds',
        'Reorder must contain every View in this Database exactly once.',
      );
    }
    final byId = <int, DatabaseViewConfig>{
      for (final view in current) view.id: view,
    };
    await store.reorderViews(
      orderedViewIds.map((id) => byId[id]!).toList(growable: false),
    );
    return store.listViews(
      workspaceId: workspaceId,
      databaseKey: databaseKey,
    );
  }

  Future<List<DatabaseViewConfig>> delete(DatabaseViewConfig view) async {
    final canonical = await _requireCurrent(view);
    final current = await store.listViews(
      workspaceId: canonical.workspaceId,
      databaseKey: canonical.databaseKey,
    );
    if (current.length <= 1) {
      throw StateError('A Database must keep at least one View.');
    }
    await store.deleteView(canonical.id);
    return store.listViews(
      workspaceId: canonical.workspaceId,
      databaseKey: canonical.databaseKey,
    );
  }

  Future<DatabaseViewConfig> _requireCurrent(DatabaseViewConfig view) async {
    final current = await store.listViews(
      workspaceId: view.workspaceId,
      databaseKey: view.databaseKey,
    );
    for (final candidate in current) {
      if (candidate.id == view.id) return candidate;
    }
    throw ArgumentError.value(
      view.id,
      'view',
      'View does not belong to the supplied workspace/Database scope.',
    );
  }

  Future<DatabaseViewConfig> _find({
    required int workspaceId,
    required String databaseKey,
    required int id,
  }) async {
    final views = await store.listViews(
      workspaceId: workspaceId,
      databaseKey: databaseKey,
    );
    return views.firstWhere((view) => view.id == id);
  }
}
