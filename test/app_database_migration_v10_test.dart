import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v10 lifecycle rows migrate through v11-v16 without losing intent', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        sqlite.execute('''
          CREATE TABLE bookmarks (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            status TEXT NOT NULL DEFAULT 'unread',
            inbox_state INTEGER NOT NULL DEFAULT 0,
            genre_state TEXT NULL,
            deleted_at_state TEXT NULL
          )
        ''');
        sqlite.execute(
          "INSERT INTO bookmarks(status, inbox_state, genre_state) "
          "VALUES ('archived', 0, 'article')",
        );
        sqlite.execute(
          "INSERT INTO bookmarks(status, inbox_state, genre_state) "
          "VALUES ('later', 1, '')",
        );
        sqlite.execute(
          "INSERT INTO bookmarks(status, inbox_state, genre_state, deleted_at_state) "
          "VALUES ('done', 1, 'video', '2026-08-31T12:34:56.000Z')",
        );
        sqlite.execute(
          "INSERT INTO bookmarks(status, inbox_state, genre_state) "
          "VALUES ('unknown', 0, NULL)",
        );

        // Minimal v10-era tables required by later v12-v16 migration steps.
        sqlite.execute(
          'CREATE TABLE tags '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)',
        );
        sqlite.execute(
          'CREATE TABLE people '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute(
          'CREATE TABLE photos '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute(
          'CREATE TABLE saved_views '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );

        sqlite.execute('PRAGMA user_version = 10');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final rows = await database.customSelect(
      'SELECT id, reading_status, storage_state, genre, deleted_at '
      'FROM bookmarks ORDER BY id',
    ).get();
    expect(rows, hasLength(4));

    expect(rows[0].read<String>('reading_status'), 'unread');
    expect(rows[0].read<String>('storage_state'), 'archived');
    expect(rows[0].read<String>('genre'), 'article');
    expect(rows[0].readNullable<int>('deleted_at'), isNull);

    expect(rows[1].read<String>('reading_status'), 'later');
    expect(rows[1].read<String>('storage_state'), 'inbox');
    expect(rows[1].read<String>('genre'), isEmpty);
    expect(rows[1].readNullable<int>('deleted_at'), isNull);

    // Trash conversion runs after inbox conversion and therefore wins.
    expect(rows[2].read<String>('reading_status'), 'done');
    expect(rows[2].read<String>('storage_state'), 'trash');
    expect(rows[2].read<String>('genre'), 'video');
    expect(rows[2].readNullable<int>('deleted_at'), isNotNull);

    expect(rows[3].read<String>('reading_status'), 'unread');
    expect(rows[3].read<String>('storage_state'), 'active');
    expect(rows[3].read<String>('genre'), isEmpty);
    expect(rows[3].readNullable<int>('deleted_at'), isNull);
  });
}
