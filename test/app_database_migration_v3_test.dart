import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v3 saved-view tag filter migrates through v4-v16', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        sqlite.execute('''
          CREATE TABLE bookmarks (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            url TEXT NOT NULL,
            title TEXT NOT NULL,
            thumbnail TEXT NULL,
            description TEXT NULL,
            tags TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
            favorite INTEGER NOT NULL DEFAULT 0
          )
        ''');
        sqlite.execute('''
          CREATE TABLE tags (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            parent_tag_id INTEGER NULL,
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
          )
        ''');
        sqlite.execute(
          "INSERT INTO tags(id, name) VALUES (3, 'Legacy tag')",
        );
        sqlite.execute('''
          CREATE TABLE bookmark_tags (
            bookmark_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            PRIMARY KEY (bookmark_id, tag_id)
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
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
          )
        ''');
        sqlite.execute(
          "INSERT INTO saved_views(id, name, layout_type, search_query, "
          "favorites_only, tag_id) VALUES "
          "(3, 'Legacy tagged view', 'table', 'needle', 1, 3)",
        );
        sqlite.execute('PRAGMA user_version = 3');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final saved = await database.customSelect(
      'SELECT id, name, layout_type, search_query, favorites_only, tag_id, '
      'tag_match_mode, sort_field, sort_direction '
      'FROM saved_views WHERE id = 3',
    ).getSingle();
    expect(saved.read<int>('id'), 3);
    expect(saved.read<String>('name'), 'Legacy tagged view');
    expect(saved.read<String>('layout_type'), 'table');
    expect(saved.read<String>('search_query'), 'needle');
    expect(saved.read<int>('favorites_only'), 1);
    expect(saved.read<int>('tag_id'), 3);
    expect(saved.read<String>('tag_match_mode'), 'or');
    expect(saved.read<String>('sort_field'), 'createdAt');
    expect(saved.read<String>('sort_direction'), 'desc');

    final migratedTag = await database.customSelect(
      'SELECT saved_view_id, tag_id FROM saved_view_tags '
      'WHERE saved_view_id = 3 AND tag_id = 3',
    ).getSingle();
    expect(migratedTag.read<int>('saved_view_id'), 3);
    expect(migratedTag.read<int>('tag_id'), 3);
  });
}
