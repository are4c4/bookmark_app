import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v4 database creates people tables through v5-v16 without losing rows', () async {
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
        sqlite.execute(
          "INSERT INTO bookmarks(id, url, title) "
          "VALUES (4, 'https://example.com/v4', 'Legacy bookmark')",
        );

        sqlite.execute('''
          CREATE TABLE tags (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            parent_tag_id INTEGER NULL,
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
          )
        ''');

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
            tag_match_mode TEXT NOT NULL DEFAULT 'or',
            sort_field TEXT NOT NULL DEFAULT 'createdAt',
            sort_direction TEXT NOT NULL DEFAULT 'desc',
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
          )
        ''');
        sqlite.execute(
          "INSERT INTO saved_views(id, name, layout_type) VALUES (4, 'Legacy view', 'table')",
        );

        sqlite.execute('''
          CREATE TABLE saved_view_tags (
            saved_view_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            PRIMARY KEY (saved_view_id, tag_id)
          )
        ''');

        sqlite.execute('PRAGMA user_version = 4');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final bookmark = await database.customSelect(
      'SELECT id, url, title FROM bookmarks WHERE id = 4',
    ).getSingle();
    expect(bookmark.read<int>('id'), 4);
    expect(bookmark.read<String>('url'), 'https://example.com/v4');
    expect(bookmark.read<String>('title'), 'Legacy bookmark');

    final view = await database.customSelect(
      'SELECT id, name, layout_type FROM saved_views WHERE id = 4',
    ).getSingle();
    expect(view.read<int>('id'), 4);
    expect(view.read<String>('name'), 'Legacy view');
    expect(view.read<String>('layout_type'), 'table');

    final tableRows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('people', 'bookmark_people')",
    ).get();
    expect(
      tableRows.map((row) => row.read<String>('name')).toSet(),
      {'people', 'bookmark_people'},
    );
  });
}
