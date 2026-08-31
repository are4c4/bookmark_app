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

  Future<void> _ensureColumn(String table, String column, String definition) async {
    final rows = await database.customSelect('PRAGMA table_info($table)').get();
    final exists = rows.any((row) => row.read<String>('name') == column);
    if (!exists) {
      await database.customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<int> initialize() async {
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS workspaces (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        icon TEXT NOT NULL DEFAULT '📁',
        color_value INTEGER NOT NULL DEFAULT 4288585374,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _ensureColumn('workspaces', 'icon', "TEXT NOT NULL DEFAULT '📁'");
    await _ensureColumn('workspaces', 'color_value', 'INTEGER NOT NULL DEFAULT 4288585374');
    await _ensureColumn('workspaces', 'sort_order', 'INTEGER NOT NULL DEFAULT 0');

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
      await database.customStatement("INSERT INTO workspaces(name, icon, sort_order) VALUES ('Default Workspace', '🏠', 0)");
      rows = await database.customSelect('SELECT id FROM workspaces ORDER BY id LIMIT 1').get();
    }
    defaultId = rows.first.read<int>('id');

    final unordered = await database.customSelect('SELECT id FROM workspaces ORDER BY created_at, id').get();
    for (var i = 0; i < unordered.length; i++) {
      await database.customStatement('UPDATE workspaces SET sort_order = ? WHERE id = ? AND sort_order = 0', [i, unordered[i].read<int>('id')]);
    }

    await database.customStatement(
      'INSERT OR IGNORE INTO bookmark_workspace(bookmark_id, workspace_id) SELECT id, ? FROM bookmarks',
      [defaultId],
    );
    await database.customStatement(
      'INSERT OR IGNORE INTO saved_view_workspace(saved_view_id, workspace_id) SELECT id, ? FROM saved_views',
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
    final rows = await database.customSelect(
      'SELECT id, name, icon, color_value, sort_order FROM workspaces ORDER BY sort_order, created_at, id',
    ).get();
    return rows
        .map((row) => WorkspaceInfo(
              id: row.read<int>('id'),
              name: row.read<String>('name'),
              icon: row.read<String>('icon'),
              colorValue: row.read<int>('color_value'),
              sortOrder: row.read<int>('sort_order'),
            ))
        .toList();
  }

  Future<bool> exists(int id) async {
    final rows = await database.customSelect(
      'SELECT 1 AS ok FROM workspaces WHERE id = ? LIMIT 1',
      variables: [Variable(id)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<int> createWorkspace(String name, {String icon = '📁', int colorValue = 4288585374}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Workspace name is empty');
    final orderRow = await database.customSelect('SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM workspaces').getSingle();
    final order = orderRow.read<int>('next_order');
    await database.customStatement(
      'INSERT INTO workspaces(name, icon, color_value, sort_order) VALUES (?, ?, ?, ?)',
      [trimmed, icon, colorValue, order],
    );
    final row = await database.customSelect(
      'SELECT id FROM workspaces WHERE name = ? LIMIT 1',
      variables: [Variable(trimmed)],
    ).getSingle();
    return row.read<int>('id');
  }

  Future<void> updateWorkspace(int id, {String? name, String? icon, int? colorValue}) async {
    if (name != null && name.trim().isNotEmpty) {
      await database.customStatement('UPDATE workspaces SET name = ? WHERE id = ?', [name.trim(), id]);
    }
    if (icon != null && icon.trim().isNotEmpty) {
      await database.customStatement('UPDATE workspaces SET icon = ? WHERE id = ?', [icon.trim(), id]);
    }
    if (colorValue != null) {
      await database.customStatement('UPDATE workspaces SET color_value = ? WHERE id = ?', [colorValue, id]);
    }
  }

  Future<void> renameWorkspace(int id, String name) => updateWorkspace(id, name: name);

  Future<void> reorderWorkspaces(List<int> orderedIds) async {
    await database.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await database.customStatement('UPDATE workspaces SET sort_order = ? WHERE id = ?', [i, orderedIds[i]]);
      }
    });
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
      "INSERT INTO workspace_settings(key, value) VALUES ('active_workspace_id', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
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
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?) ON CONFLICT(bookmark_id) DO UPDATE SET workspace_id = excluded.workspace_id',
      [bookmarkId, workspaceId],
    );
  }

  Future<void> assignSavedView(int savedViewId, int workspaceId) async {
    await database.customStatement(
      'INSERT INTO saved_view_workspace(saved_view_id, workspace_id) VALUES (?, ?) ON CONFLICT(saved_view_id) DO UPDATE SET workspace_id = excluded.workspace_id',
      [savedViewId, workspaceId],
    );
  }

  Future<void> moveBookmarks(Iterable<int> bookmarkIds, int workspaceId) async {
    await database.transaction(() async {
      for (final id in bookmarkIds.toSet()) {
        await assignBookmark(id, workspaceId);
      }
    });
  }
}
