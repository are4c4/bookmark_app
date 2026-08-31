import 'package:drift/drift.dart';

import 'app_database.dart';

class WorkspaceInfo {
  const WorkspaceInfo({required this.id, required this.name});

  final int id;
  final String name;
}

class WorkspaceStore {
  WorkspaceStore(this.database);

  final AppDatabase database;

  Future<int> initialize() async {
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS workspaces (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS bookmark_workspace (
        bookmark_id INTEGER PRIMARY KEY,
        workspace_id INTEGER NOT NULL,
        FOREIGN KEY(bookmark_id) REFERENCES bookmarks(id) ON DELETE CASCADE,
        FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS saved_view_workspace (
        saved_view_id INTEGER PRIMARY KEY,
        workspace_id INTEGER NOT NULL,
        FOREIGN KEY(saved_view_id) REFERENCES saved_views(id) ON DELETE CASCADE,
        FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS workspace_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    var rows = await database.customSelect('SELECT id FROM workspaces ORDER BY id LIMIT 1').get();
    int defaultId;
    if (rows.isEmpty) {
      await database.customStatement("INSERT INTO workspaces(name) VALUES ('Default Workspace')");
      rows = await database.customSelect('SELECT id FROM workspaces ORDER BY id LIMIT 1').get();
    }
    defaultId = rows.first.read<int>('id');

    await database.customStatement(
      'INSERT OR IGNORE INTO bookmark_workspace(bookmark_id, workspace_id) '
      'SELECT id, ? FROM bookmarks',
      [defaultId],
    );
    await database.customStatement(
      'INSERT OR IGNORE INTO saved_view_workspace(saved_view_id, workspace_id) '
      'SELECT id, ? FROM saved_views',
      [defaultId],
    );

    final activeRows = await database.customSelect(
      "SELECT value FROM workspace_settings WHERE key = 'active_workspace_id' LIMIT 1",
    ).get();
    var activeId = defaultId;
    if (activeRows.isNotEmpty) {
      final parsed = int.tryParse(activeRows.first.read<String>('value'));
      if (parsed != null && await exists(parsed)) activeId = parsed;
    }
    await setActiveWorkspace(activeId);
    return activeId;
  }

  Future<List<WorkspaceInfo>> listWorkspaces() async {
    final rows = await database.customSelect('SELECT id, name FROM workspaces ORDER BY created_at, id').get();
    return rows
        .map((row) => WorkspaceInfo(id: row.read<int>('id'), name: row.read<String>('name')))
        .toList();
  }

  Future<bool> exists(int id) async {
    final rows = await database.customSelect('SELECT 1 AS ok FROM workspaces WHERE id = ? LIMIT 1', variables: [Variable(id)]).get();
    return rows.isNotEmpty;
  }

  Future<int> createWorkspace(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Workspace name is empty');
    await database.customStatement('INSERT INTO workspaces(name) VALUES (?)', [trimmed]);
    final row = await database.customSelect('SELECT id FROM workspaces WHERE name = ? LIMIT 1', variables: [Variable(trimmed)]).getSingle();
    return row.read<int>('id');
  }

  Future<void> renameWorkspace(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await database.customStatement('UPDATE workspaces SET name = ? WHERE id = ?', [trimmed, id]);
  }

  Future<void> deleteWorkspace(int id) async {
    final all = await listWorkspaces();
    if (all.length <= 1) throw StateError('At least one workspace is required');
    final fallback = all.firstWhere((workspace) => workspace.id != id);
    await database.transaction(() async {
      await database.customStatement('UPDATE bookmark_workspace SET workspace_id = ? WHERE workspace_id = ?', [fallback.id, id]);
      await database.customStatement('UPDATE saved_view_workspace SET workspace_id = ? WHERE workspace_id = ?', [fallback.id, id]);
      await database.customStatement('DELETE FROM workspaces WHERE id = ?', [id]);
    });
    await setActiveWorkspace(fallback.id);
  }

  Future<void> setActiveWorkspace(int id) async {
    await database.customStatement(
      "INSERT INTO workspace_settings(key, value) VALUES ('active_workspace_id', ?) "
      "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
      ['$id'],
    );
  }

  Future<Set<int>> bookmarkIds(int workspaceId) async {
    final rows = await database.customSelect(
      'SELECT bookmark_id FROM bookmark_workspace WHERE workspace_id = ?',
      variables: [Variable(workspaceId)],
    ).get();
    return rows.map((row) => row.read<int>('bookmark_id')).toSet();
  }

  Future<Set<int>> savedViewIds(int workspaceId) async {
    final rows = await database.customSelect(
      'SELECT saved_view_id FROM saved_view_workspace WHERE workspace_id = ?',
      variables: [Variable(workspaceId)],
    ).get();
    return rows.map((row) => row.read<int>('saved_view_id')).toSet();
  }

  Future<void> assignBookmark(int bookmarkId, int workspaceId) async {
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?) '
      'ON CONFLICT(bookmark_id) DO UPDATE SET workspace_id = excluded.workspace_id',
      [bookmarkId, workspaceId],
    );
  }

  Future<void> assignSavedView(int savedViewId, int workspaceId) async {
    await database.customStatement(
      'INSERT INTO saved_view_workspace(saved_view_id, workspace_id) VALUES (?, ?) '
      'ON CONFLICT(saved_view_id) DO UPDATE SET workspace_id = excluded.workspace_id',
      [savedViewId, workspaceId],
    );
  }

  Future<void> moveBookmarks(Iterable<int> bookmarkIds, int workspaceId) async {
    for (final id in bookmarkIds.toSet()) {
      await assignBookmark(id, workspaceId);
    }
  }
}
