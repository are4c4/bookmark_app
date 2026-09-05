import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v2 bookmark tags normalize through v3-v16', () async {
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
          "INSERT INTO bookmarks(id, url, title, tags, favorite) VALUES "
          "(2, 'https://example.com/v2', 'Legacy bookmark', "
          "' Fruit, fruit, Travel, TRAVEL,  ', 1)",
        );
        sqlite.execute('PRAGMA user_version = 2');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final bookmark = await database.customSelect(
      'SELECT id, url, title, favorite FROM bookmarks WHERE id = 2',
    ).getSingle();
    expect(bookmark.read<int>('id'), 2);
    expect(bookmark.read<String>('url'), 'https://example.com/v2');
    expect(bookmark.read<String>('title'), 'Legacy bookmark');
    expect(bookmark.read<int>('favorite'), 1);

    final tagRows = await database.customSelect(
      'SELECT t.name FROM tags t '
      'JOIN bookmark_tags bt ON bt.tag_id = t.id '
      'WHERE bt.bookmark_id = 2 ORDER BY t.name',
    ).get();
    expect(
      tagRows.map((row) => row.read<String>('name')).toSet(),
      {'Fruit', 'Travel'},
    );
  });
}
