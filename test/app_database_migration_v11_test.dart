import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v11 legacy workspace upgrades through v12-v16 without losing workspace data', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        // v12 formalized workspace storage that previously existed behind
        // manual SQL. Exercise the compatibility branch for an older workspace
        // table that predates icon/color/order metadata.
        sqlite.execute('''
          CREATE TABLE workspaces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        sqlite.execute(
          "INSERT INTO workspaces (name, created_at) "
          "VALUES ('Legacy Workspace', '2026-01-02 03:04:05')",
        );

        // Minimal v11-era tables needed by subsequent v13-v16 migrations.
        sqlite.execute(
          'CREATE TABLE bookmarks '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute('''
          CREATE TABLE tags (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            parent_tag_id INTEGER NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
          )
        ''');
        sqlite.execute('''
          CREATE TABLE saved_views (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            layout_type TEXT NOT NULL DEFAULT 'gallery',
            search_query TEXT NOT NULL DEFAULT '',
            favorites_only INTEGER NOT NULL DEFAULT 0,
            tag_id INTEGER NULL,
            tag_match_mode TEXT NOT NULL DEFAULT 'or',
            sort_field TEXT NOT NULL DEFAULT 'createdAt',
            sort_direction TEXT NOT NULL DEFAULT 'desc',
            visible_properties TEXT NOT NULL DEFAULT 'image,url,tags,favorite',
            status_filter TEXT NOT NULL DEFAULT '',
            min_rating INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
          )
        ''');
        sqlite.execute(
          'CREATE TABLE people '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute(
          'CREATE TABLE photos '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );

        sqlite.execute('PRAGMA user_version = 11');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final workspace = await database.customSelect(
      "SELECT id, name, created_at, icon, color_value, sort_order "
      "FROM workspaces WHERE name = 'Legacy Workspace'",
    ).getSingle();
    expect(workspace.read<int>('id'), 1);
    expect(workspace.read<String>('name'), 'Legacy Workspace');
    expect(workspace.read<String>('created_at'), '2026-01-02 03:04:05');
    expect(workspace.read<String>('icon'), '📁');
    expect(workspace.read<int>('color_value'), 4288585374);
    expect(workspace.read<int>('sort_order'), 0);

    final tableRows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final tables = tableRows.map((row) => row.read<String>('name')).toSet();
    expect(
      tables,
      containsAll(<String>{
        'bookmark_workspace',
        'saved_view_workspace',
        'workspace_settings',
      }),
    );
  });
}
