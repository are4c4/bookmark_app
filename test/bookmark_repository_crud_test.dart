import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();

    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<BookmarkItem> itemById(int id) async =>
      (await repository.watchAll().first).firstWhere((item) => item.id == id);

  test('create persists bookmark fields and workspace visibility', () async {
    final id = await repository.create(
      url: 'https://example.com/original',
      title: 'Original title',
      description: 'Original description',
      tagNames: const ['Flutter', 'Read later'],
      personNames: const ['Alice'],
      favorite: true,
      status: 'reading',
      rating: 4,
    );

    final bookmark = await itemById(id);

    expect(bookmark.url, 'https://example.com/original');
    expect(bookmark.title, 'Original title');
    expect(bookmark.description, 'Original description');
    expect(bookmark.favorite, isTrue);
    expect(bookmark.status, 'reading');
    expect(bookmark.rating, 4);
    expect(
      bookmark.tags.map((tag) => tag.name),
      containsAll(['Flutter', 'Read later']),
    );
    expect(bookmark.people.map((person) => person.name), contains('Alice'));
  });

  test('update replaces editable fields and related metadata', () async {
    final id = await repository.create(
      url: 'https://example.com/original',
      title: 'Original title',
      description: 'Original description',
      tagNames: const ['Old tag'],
      personNames: const ['Alice'],
      status: 'unread',
      rating: 1,
    );

    await repository.update(
      id: id,
      url: 'https://example.com/updated',
      title: 'Updated title',
      description: 'Updated description',
      tagNames: const ['New tag'],
      personNames: const ['Bob'],
      status: 'read',
      rating: 5,
    );

    final bookmark = await itemById(id);

    expect(bookmark.url, 'https://example.com/updated');
    expect(bookmark.title, 'Updated title');
    expect(bookmark.description, 'Updated description');
    expect(bookmark.status, 'read');
    expect(bookmark.rating, 5);
    expect(bookmark.tags.map((tag) => tag.name), contains('New tag'));
    expect(bookmark.tags.map((tag) => tag.name), isNot(contains('Old tag')));
    expect(bookmark.people.map((person) => person.name), contains('Bob'));
    expect(bookmark.people.map((person) => person.name), isNot(contains('Alice')));
  });

  test('favorite and single-item metadata actions persist', () async {
    final id = await repository.create(
      url: 'https://example.com/actions',
      title: 'Actions',
    );
    var bookmark = await itemById(id);

    await repository.toggleFavorite(bookmark);
    bookmark = await itemById(id);
    expect(bookmark.favorite, isTrue);

    await repository.setStatus(bookmark, 'reading');
    bookmark = await itemById(id);
    expect(bookmark.status, 'reading');

    await repository.setRating(bookmark, 3);
    bookmark = await itemById(id);
    expect(bookmark.rating, 3);
  });

  test('batch actions update tags people status rating and favorite', () async {
    final firstId = await repository.create(
      url: 'https://example.com/one',
      title: 'One',
      tagNames: const ['Keep'],
      personNames: const ['Alice'],
    );
    final secondId = await repository.create(
      url: 'https://example.com/two',
      title: 'Two',
      tagNames: const ['Keep'],
      personNames: const ['Alice'],
    );
    final ids = [firstId, secondId];

    await repository.batchAddTags(ids, const ['Batch']);
    await repository.batchRemoveTags(ids, const ['Keep']);
    await repository.batchAddPeople(ids, const ['Bob']);
    await repository.batchRemovePeople(ids, const ['Alice']);
    await repository.batchSetStatus(ids, 'read');
    await repository.batchSetRating(ids, 5);
    await repository.batchSetFavorite(ids, true);

    final items = await repository.watchAll().first;
    for (final id in ids) {
      final item = items.firstWhere((candidate) => candidate.id == id);
      expect(item.tags.map((tag) => tag.name), contains('Batch'));
      expect(item.tags.map((tag) => tag.name), isNot(contains('Keep')));
      expect(item.people.map((person) => person.name), contains('Bob'));
      expect(item.people.map((person) => person.name), isNot(contains('Alice')));
      expect(item.status, 'read');
      expect(item.rating, 5);
      expect(item.favorite, isTrue);
    }
  });

  test('delete moves bookmark to trash without permanently deleting it', () async {
    final id = await repository.create(
      url: 'https://example.com/delete-me',
      title: 'Delete me',
    );

    await repository.delete(id);

    expect(
      (await repository.watchAll().first).any((item) => item.id == id),
      isFalse,
    );
    expect(
      (await repository.watchTrash().first).any((item) => item.id == id),
      isTrue,
    );

    final row = await (database.select(database.bookmarks)
          ..where((item) => item.id.equals(id)))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.storageState, 'trashed');
  });
}
