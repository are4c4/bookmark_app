import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_read_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregates Bookmark metadata and resolves managed photo paths', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: '/profiles/current',
    );
    addTearDown(database.close);

    final bookmarkId = await database.addBookmark(
      url: 'https://example.com/read-store',
      title: 'Read store',
      tagNames: const ['Zulu', 'alpha'],
      personNames: const ['Bob', 'alice'],
    );
    final photoId = await database.addPhoto(
      path: 'photos/cover.jpg',
      title: 'Cover',
    );
    await database.attachPhotoToBookmark(bookmarkId, photoId, asCover: true);
    await database.setBookmarkCollections(
      bookmarkId,
      const ['Zulu collection', 'alpha collection'],
    );

    final item = (await BookmarkReadStore(database).watchItems().first).single;

    expect(item.id, bookmarkId);
    expect(item.tags.map((tag) => tag.name).toList(), ['alpha', 'Zulu']);
    expect(item.people.map((person) => person.name).toList(), ['alice', 'Bob']);
    expect(
      item.collections.map((collection) => collection.name).toList(),
      ['alpha collection', 'Zulu collection'],
    );
    expect(item.photos, hasLength(1));
    expect(item.photos.single.path, '/profiles/current/photos/cover.jpg');
    expect(item.coverPhoto?.id, photoId);
    expect(item.coverPhoto?.path, '/profiles/current/photos/cover.jpg');
  });
}
