import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_engagement_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkEngagementStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = BookmarkEngagementStore(database);
  });

  tearDown(() => database.close());

  Future<BookmarkItem> readBookmark(int id) =>
      (database.select(database.bookmarks)..where((row) => row.id.equals(id)))
          .getSingle();

  test('single engagement mutations preserve Bookmark storage semantics', () async {
    final id = await database.addBookmark(
      url: 'https://example.com/single',
      title: 'Single',
    );

    await store.setFavorite(id, true);
    await store.setRating(id, 9);
    await store.setStatus(id, 'archived');

    final bookmark = await readBookmark(id);
    expect(bookmark.favorite, isTrue);
    expect(bookmark.rating, 5);
    expect(bookmark.status, 'archived');
    expect(bookmark.readingStatus, 'unread');
    expect(bookmark.storageState, 'archived');
  });

  test('batch engagement mutations update each unique Bookmark', () async {
    final first = await database.addBookmark(
      url: 'https://example.com/first',
      title: 'First',
    );
    final second = await database.addBookmark(
      url: 'https://example.com/second',
      title: 'Second',
    );

    final ids = <int>[first, second, first];
    await store.batchSetFavorite(ids, true);
    await store.batchSetRating(ids, -3);
    await store.batchSetStatus(ids, 'done');

    for (final id in <int>[first, second]) {
      final bookmark = await readBookmark(id);
      expect(bookmark.favorite, isTrue);
      expect(bookmark.rating, 0);
      expect(bookmark.status, 'done');
      expect(bookmark.readingStatus, 'done');
      expect(bookmark.storageState, 'active');
    }
  });

  test('recordOpen increments history and missing Bookmark remains a no-op', () async {
    final id = await database.addBookmark(
      url: 'https://example.com/open',
      title: 'Open',
    );

    final before = await readBookmark(id);
    expect(before.openCount, 0);
    expect(before.lastOpenedAt, isNull);

    await store.recordOpen(id);
    await store.recordOpen(id);
    await store.recordOpen(999999);

    final after = await readBookmark(id);
    expect(after.openCount, 2);
    expect(after.lastOpenedAt, isNotNull);
  });
}
