import 'package:drift/drift.dart';

import 'app_database.dart';

class WorkspaceInfo {
  const WorkspaceInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String icon;
  final int colorValue;
  final int sortOrder;

  WorkspaceInfo copyWith({String? name, String? icon, int? colorValue, int? sortOrder}) => WorkspaceInfo(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        colorValue: colorValue ?? this.colorValue,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

class WorkspaceStore {
  WorkspaceStore(this.database);

  final AppDatabase database;

  WorkspaceInfo _toInfo(WorkspaceRecord row) => WorkspaceInfo(
        id: row.id,
        name: row.name,
        icon: row.icon,
        colorValue: row.colorValue,
        sortOrder: row.sortOrder,
      );

  Future<int> initialize() async {
    var rows = await (database.select(database.workspaces)
          ..orderBy([
            (workspace) => OrderingTerm.asc(workspace.sortOrder),
            (workspace) => OrderingTerm.asc(workspace.createdAt),
            (workspace) => OrderingTerm.asc(workspace.id),
          ]))
        .get();

    if (rows.isEmpty) {
      final id = await database.into(database.workspaces).insert(
            WorkspacesCompanion.insert(
              name: 'Default Workspace',
              icon: const Value('🏠'),
              sortOrder: const Value(0),
            ),
          );
      rows = [
        (await (database.select(database.workspaces)..where((workspace) => workspace.id.equals(id))).getSingle()),
      ];
    }

    for (var i = 0; i < rows.length; i++) {
      if (rows[i].sortOrder == i) continue;
      await (database.update(database.workspaces)..where((workspace) => workspace.id.equals(rows[i].id))).write(
        WorkspacesCompanion(sortOrder: Value(i)),
      );
    }

    final defaultId = rows.first.id;

    final bookmarkRows = await database.select(database.bookmarks).get();
    final assignedBookmarks = await database.select(database.bookmarkWorkspaces).get();
    final assignedBookmarkIds = assignedBookmarks.map((row) => row.bookmarkId).toSet();
    for (final bookmark in bookmarkRows) {
      if (assignedBookmarkIds.contains(bookmark.id)) continue;
      await database.into(database.bookmarkWorkspaces).insert(
            BookmarkWorkspacesCompanion.insert(
              bookmarkId: Value(bookmark.id),
              workspaceId: defaultId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }

    final viewRows = await database.select(database.savedViews).get();
    final assignedViews = await database.select(database.savedViewWorkspaces).get();
    final assignedViewIds = assignedViews.map((row) => row.savedViewId).toSet();
    for (final view in viewRows) {
      if (assignedViewIds.contains(view.id)) continue;
      await database.into(database.savedViewWorkspaces).insert(
            SavedViewWorkspacesCompanion.insert(
              savedViewId: Value(view.id),
              workspaceId: defaultId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }

    final active = await (database.select(database.workspaceSettings)
          ..where((setting) => setting.key.equals('active_workspace_id')))
        .getSingleOrNull();
    final parsed = active == null ? null : int.tryParse(active.value);
    final activeId = parsed != null && await exists(parsed) ? parsed : defaultId;
    await setActiveWorkspace(activeId);
    return activeId;
  }

  Stream<List<WorkspaceInfo>> watchWorkspaces() => (database.select(database.workspaces)
        ..orderBy([
          (workspace) => OrderingTerm.asc(workspace.sortOrder),
          (workspace) => OrderingTerm.asc(workspace.createdAt),
          (workspace) => OrderingTerm.asc(workspace.id),
        ]))
      .watch()
      .map((rows) => rows.map(_toInfo).toList());

  Future<List<WorkspaceInfo>> listWorkspaces() async =>
      (await (database.select(database.workspaces)
                ..orderBy([
                  (workspace) => OrderingTerm.asc(workspace.sortOrder),
                  (workspace) => OrderingTerm.asc(workspace.createdAt),
                  (workspace) => OrderingTerm.asc(workspace.id),
                ]))
              .get())
          .map(_toInfo)
          .toList();

  Future<bool> exists(int id) async =>
      await (database.select(database.workspaces)..where((workspace) => workspace.id.equals(id))).getSingleOrNull() != null;

  Future<int> createWorkspace(
    String name, {
    String icon = '📁',
    int colorValue = 4288585374,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Workspace name is empty');

    final all = await database.select(database.workspaces).get();
    final nextOrder = all.isEmpty
        ? 0
        : all.map((workspace) => workspace.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    return database.into(database.workspaces).insert(
          WorkspacesCompanion.insert(
            name: trimmed,
            icon: Value(icon),
            colorValue: Value(colorValue),
            sortOrder: Value(nextOrder),
          ),
        );
  }

  Future<void> updateWorkspace(
    int id, {
    String? name,
    String? icon,
    int? colorValue,
  }) async {
    final trimmedName = name?.trim();
    final trimmedIcon = icon?.trim();
    await (database.update(database.workspaces)..where((workspace) => workspace.id.equals(id))).write(
      WorkspacesCompanion(
        name: trimmedName == null || trimmedName.isEmpty ? const Value.absent() : Value(trimmedName),
        icon: trimmedIcon == null || trimmedIcon.isEmpty ? const Value.absent() : Value(trimmedIcon),
        colorValue: colorValue == null ? const Value.absent() : Value(colorValue),
      ),
    );
  }

  Future<void> renameWorkspace(int id, String name) => updateWorkspace(id, name: name);

  Future<void> reorderWorkspaces(List<int> orderedIds) => database.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (database.update(database.workspaces)..where((workspace) => workspace.id.equals(orderedIds[i]))).write(
            WorkspacesCompanion(sortOrder: Value(i)),
          );
        }
      });

  Future<void> deleteWorkspace(int id) async {
    final all = await listWorkspaces();
    if (all.length <= 1) throw StateError('At least one workspace is required');
    final fallback = all.firstWhere((workspace) => workspace.id != id);

    await database.transaction(() async {
      await (database.update(database.bookmarkWorkspaces)..where((relation) => relation.workspaceId.equals(id))).write(
        BookmarkWorkspacesCompanion(workspaceId: Value(fallback.id)),
      );
      await (database.update(database.savedViewWorkspaces)..where((relation) => relation.workspaceId.equals(id))).write(
        SavedViewWorkspacesCompanion(workspaceId: Value(fallback.id)),
      );
      await (database.delete(database.workspaces)..where((workspace) => workspace.id.equals(id))).go();
    });

    final active = await activeWorkspaceId();
    if (active == id) await setActiveWorkspace(fallback.id);
  }

  Future<int?> activeWorkspaceId() async {
    final setting = await (database.select(database.workspaceSettings)
          ..where((row) => row.key.equals('active_workspace_id')))
        .getSingleOrNull();
    return setting == null ? null : int.tryParse(setting.value);
  }

  Future<void> setActiveWorkspace(int id) => database.into(database.workspaceSettings).insertOnConflictUpdate(
        WorkspaceSettingsCompanion.insert(
          key: 'active_workspace_id',
          value: '$id',
        ),
      );

  Stream<Set<int>> watchBookmarkIds(int workspaceId) =>
      (database.select(database.bookmarkWorkspaces)..where((relation) => relation.workspaceId.equals(workspaceId)))
          .watch()
          .map((rows) => rows.map((row) => row.bookmarkId).toSet());

  Future<Set<int>> bookmarkIds(int workspaceId) async =>
      (await (database.select(database.bookmarkWorkspaces)..where((relation) => relation.workspaceId.equals(workspaceId))).get())
          .map((row) => row.bookmarkId)
          .toSet();

  Stream<Set<int>> watchSavedViewIds(int workspaceId) =>
      (database.select(database.savedViewWorkspaces)..where((relation) => relation.workspaceId.equals(workspaceId)))
          .watch()
          .map((rows) => rows.map((row) => row.savedViewId).toSet());

  Future<Set<int>> savedViewIds(int workspaceId) async =>
      (await (database.select(database.savedViewWorkspaces)..where((relation) => relation.workspaceId.equals(workspaceId))).get())
          .map((row) => row.savedViewId)
          .toSet();

  Future<void> assignBookmark(int bookmarkId, int workspaceId) =>
      database.into(database.bookmarkWorkspaces).insertOnConflictUpdate(
            BookmarkWorkspacesCompanion.insert(
              bookmarkId: Value(bookmarkId),
              workspaceId: workspaceId,
            ),
          );

  Future<void> assignSavedView(int savedViewId, int workspaceId) =>
      database.into(database.savedViewWorkspaces).insertOnConflictUpdate(
            SavedViewWorkspacesCompanion.insert(
              savedViewId: Value(savedViewId),
              workspaceId: workspaceId,
            ),
          );

  Future<void> moveBookmarks(Iterable<int> bookmarkIds, int workspaceId) => database.transaction(() async {
        for (final id in bookmarkIds.toSet()) {
          await assignBookmark(id, workspaceId);
        }
      });
}
