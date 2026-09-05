import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v13 database upgrades through v14-v16 without losing saved views', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        // Minimal real v13-era shape required by the v14 migration. The v14
        // source revision added exactly the three columns asserted below; v15
        // and v16 then add new tables without rewriting this row.
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
          "INSERT INTO saved_views (name, search_query) VALUES ('Legacy view', 'needle')",
        );

        // Foreign-key targets referenced by columns/tables created in v14-v16.
        // Only identity is needed for this migration regression.
        sqlite.execute('CREATE TABLE people (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)');
        sqlite.execute('CREATE TABLE photos (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)');
        sqlite.execute('CREATE TABLE workspaces (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)');

        sqlite.execute('PRAGMA user_version = 13');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    // Opening the current database must execute v14, v15 and v16 in order.
    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final columns = await database.customSelect('PRAGMA table_info(saved_views)').get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>{
        'include_descendants',
        'person_filter_id',
        'photo_filter_id',
      }),
    );

    final saved = await database.customSelect(
      'SELECT name, search_query, include_descendants, person_filter_id, photo_filter_id '
      'FROM saved_views WHERE name = ?',
      variables: [const Variable<String>('Legacy view')],
    ).getSingle();
    expect(saved.read<String>('name'), 'Legacy view');
    expect(saved.read<String>('search_query'), 'needle');
    expect(saved.read<int>('include_descendants'), 1);
    expect(saved.readNullable<int>('person_filter_id'), isNull);
    expect(saved.readNullable<int>('photo_filter_id'), isNull);

    final tableRows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final tables = tableRows.map((row) => row.read<String>('name')).toSet();
    expect(
      tables,
      containsAll(<String>{
        'person_groups',
        'person_group_members',
        'database_views',
        'generic_databases',
        'generic_properties',
        'generic_records',
        'generic_values',
      }),
    );
  });
}
