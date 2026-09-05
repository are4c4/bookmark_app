import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v1 bookmark upgrades through v2-v16 without losing data', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        sqlite.execute('''
          CREATE TABLE bookmarks (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            url TEXT NOT NULL,
            title TEXT NOT NULL,
            thumbnail TEXT NULL,
            description TEXT NULL,
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
            favorite INTEGER NOT NULL DEFAULT 0
          )
        ''');
        sqlite.execute(
          "INSERT INTO bookmarks(id, url, title, favorite) VALUES "
          "(1, 'https://example.com/v1', 'Original bookmark', 1)",
        );
        sqlite.execute('PRAGMA user_version = 1');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final bookmark = await database.customSelect(
      'SELECT id, url, title, favorite, tags FROM bookmarks WHERE id = 1',
    ).getSingle();
    expect(bookmark.read<int>('id'), 1);
    expect(bookmark.read<String>('url'), 'https://example.com/v1');
    expect(bookmark.read<String>('title'), 'Original bookmark');
    expect(bookmark.read<int>('favorite'), 1);
    expect(bookmark.read<String>('tags'), '');

    final normalizedTags = await database.customSelect(
      'SELECT COUNT(*) AS count FROM bookmark_tags WHERE bookmark_id = 1',
    ).getSingle();
    expect(normalizedTags.read<int>('count'), 0);
  });
}
