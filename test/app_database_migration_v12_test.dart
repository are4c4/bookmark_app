import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v12 database upgrades through v13-v16 without losing tags', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        // Exact v12-era shapes needed by the v13 boundary, based on the parent
        // of commit 06566fc (schemaVersion 12 -> 13).
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
        sqlite.execute("INSERT INTO tags (name) VALUES ('Legacy tag')");

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

        // Foreign-key targets required by later v14-v16 table/column creation.
        sqlite.execute(
          'CREATE TABLE people '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute(
          'CREATE TABLE photos '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute(
          'CREATE TABLE workspaces '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );

        sqlite.execute('PRAGMA user_version = 12');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final tagColumns = await database.customSelect('PRAGMA table_info(tags)').get();
    expect(
      tagColumns.map((row) => row.read<String>('name')),
      contains('group_id'),
    );
    final legacyTag = await database.customSelect(
      "SELECT name, group_id FROM tags WHERE name = 'Legacy tag'",
    ).getSingle();
    expect(legacyTag.read<String>('name'), 'Legacy tag');
    expect(legacyTag.readNullable<int>('group_id'), isNull);

    final tableRows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final tables = tableRows.map((row) => row.read<String>('name')).toSet();
    expect(
      tables,
      containsAll(<String>{
        'tag_groups',
        'bookmark_attachments',
        'pdf_annotations',
      }),
    );

    final indexRows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    ).get();
    final indexes = indexRows.map((row) => row.read<String>('name')).toSet();
    expect(
      indexes,
      containsAll(<String>{
        'bookmark_attachments_bookmark_id_idx',
        'pdf_annotations_attachment_idx',
      }),
    );
  });
}
