import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v8 rows migrate through v9-v16 with workflow defaults intact', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        // Exact schemaVersion 8 shapes needed by later migration steps.
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
          "INSERT INTO bookmarks(id, url, title, tags, favorite) "
          "VALUES (7, 'https://example.com', 'Legacy bookmark', 'alpha', 1)",
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
        sqlite.execute("INSERT INTO people(id, name, note) VALUES (3, 'Legacy person', 'note')");

        sqlite.execute('''
          CREATE TABLE bookmark_people (
            bookmark_id INTEGER NOT NULL,
            person_id INTEGER NOT NULL,
            role TEXT NOT NULL DEFAULT '出演',
            PRIMARY KEY (bookmark_id, person_id)
          )
        ''');
        sqlite.execute(
          "INSERT INTO bookmark_people(bookmark_id, person_id, role) VALUES (7, 3, '出演')",
        );

        sqlite.execute('''
          CREATE TABLE photos (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL UNIQUE,
            title TEXT NULL,
            note TEXT NULL,
            tags TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
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
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
          )
        ''');
        sqlite.execute(
          "INSERT INTO saved_views(id, name, layout_type, search_query, favorites_only) "
          "VALUES (5, 'Legacy view', 'table', 'needle', 1)",
        );

        sqlite.execute('PRAGMA user_version = 8');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final bookmark = await database.customSelect(
      'SELECT id, url, title, favorite, status, rating, last_opened_at, open_count '
      'FROM bookmarks WHERE id = 7',
    ).getSingle();
    expect(bookmark.read<int>('id'), 7);
    expect(bookmark.read<String>('url'), 'https://example.com');
    expect(bookmark.read<String>('title'), 'Legacy bookmark');
    expect(bookmark.read<int>('favorite'), 1);
    expect(bookmark.read<String>('status'), 'unread');
    expect(bookmark.read<int>('rating'), 0);
    expect(bookmark.readNullable<int>('last_opened_at'), isNull);
    expect(bookmark.read<int>('open_count'), 0);

    final person = await database.customSelect(
      'SELECT id, name, note, profile_photo_id FROM people WHERE id = 3',
    ).getSingle();
    expect(person.read<int>('id'), 3);
    expect(person.read<String>('name'), 'Legacy person');
    expect(person.read<String>('note'), 'note');
    expect(person.readNullable<int>('profile_photo_id'), isNull);

    final view = await database.customSelect(
      'SELECT id, name, layout_type, search_query, favorites_only, status_filter, min_rating '
      'FROM saved_views WHERE id = 5',
    ).getSingle();
    expect(view.read<int>('id'), 5);
    expect(view.read<String>('name'), 'Legacy view');
    expect(view.read<String>('layout_type'), 'table');
    expect(view.read<String>('search_query'), 'needle');
    expect(view.read<int>('favorites_only'), 1);
    expect(view.read<String>('status_filter'), isEmpty);
    expect(view.read<int>('min_rating'), 0);

    final tables = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('collections', 'bookmark_collections', 'bookmark_relations')",
    ).get();
    expect(
      tables.map((row) => row.read<String>('name')).toSet(),
      {'collections', 'bookmark_collections', 'bookmark_relations'},
    );
  });
}
