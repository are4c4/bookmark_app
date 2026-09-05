import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v9 person roles migrate through v10-v16 without losing relations', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        sqlite.execute(
          'CREATE TABLE bookmarks '
          "(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, status TEXT NOT NULL DEFAULT 'unread')",
        );
        sqlite.execute('INSERT INTO bookmarks(id, status) VALUES (1, \'unread\')');

        sqlite.execute(
          'CREATE TABLE people '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute('INSERT INTO people(id) VALUES (1), (2), (3)');

        // Exact v9 primary-key shape before multi-role support.
        sqlite.execute('''
          CREATE TABLE bookmark_people (
            bookmark_id INTEGER NOT NULL,
            person_id INTEGER NOT NULL,
            role TEXT NOT NULL DEFAULT '出演',
            PRIMARY KEY (bookmark_id, person_id)
          )
        ''');
        sqlite.execute(
          "INSERT INTO bookmark_people(bookmark_id, person_id, role) VALUES "
          "(1, 1, '出演'), (1, 2, 'performer'), (1, 3, '監督')",
        );

        // Minimal tables required by later v12-v16 migration steps.
        sqlite.execute(
          'CREATE TABLE tags '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)',
        );
        sqlite.execute(
          'CREATE TABLE photos '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute(
          'CREATE TABLE saved_views '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );

        sqlite.execute('PRAGMA user_version = 9');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final rows = await database.customSelect(
      'SELECT bookmark_id, person_id, role FROM bookmark_people '
      'ORDER BY person_id, role',
    ).get();
    expect(rows, hasLength(3));
    expect(rows[0].read<int>('person_id'), 1);
    expect(rows[0].read<String>('role'), '出演者');
    expect(rows[1].read<int>('person_id'), 2);
    expect(rows[1].read<String>('role'), '出演者');
    expect(rows[2].read<int>('person_id'), 3);
    expect(rows[2].read<String>('role'), '監督');

    final oldTable = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'bookmark_people_old'",
    ).get();
    expect(oldTable, isEmpty);

    // v10 expands the primary key to include role, so one person can carry a
    // second role for the same bookmark after the migration.
    await database.customStatement(
      "INSERT INTO bookmark_people(bookmark_id, person_id, role) VALUES (1, 1, '監督')",
    );
    final multiRole = await database.customSelect(
      'SELECT role FROM bookmark_people WHERE bookmark_id = 1 AND person_id = 1 ORDER BY role',
    ).get();
    expect(multiRole.map((row) => row.read<String>('role')).toSet(), {'出演者', '監督'});
  });
}
