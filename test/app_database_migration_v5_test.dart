import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v5 database creates photo tables through v6-v16 without losing rows', () async {
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
          "VALUES (5, 'https://example.com/v5', 'Legacy bookmark')",
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
          CREATE TABLE people (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            note TEXT NULL,
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
          )
        ''');

        sqlite.execute('''
          CREATE TABLE bookmark_people (
            bookmark_id INTEGER NOT NULL,
            person_id INTEGER NOT NULL,
            role TEXT NOT NULL DEFAULT '出演',
            PRIMARY KEY (bookmark_id, person_id)
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

        sqlite.execute('PRAGMA user_version = 5');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final bookmark = await database.customSelect(
      'SELECT id, url, title FROM bookmarks WHERE id = 5',
    ).getSingle();
    expect(bookmark.read<int>('id'), 5);
    expect(bookmark.read<String>('url'), 'https://example.com/v5');
    expect(bookmark.read<String>('title'), 'Legacy bookmark');

    final tableRows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('photos', 'bookmark_photos')",
    ).get();
    expect(
      tableRows.map((row) => row.read<String>('name')).toSet(),
      {'photos', 'bookmark_photos'},
    );

    final photoColumns = await database.customSelect('PRAGMA table_info(photos)').get();
    expect(
      photoColumns.map((row) => row.read<String>('name')).toSet(),
      contains('tags'),
    );
  });
}
