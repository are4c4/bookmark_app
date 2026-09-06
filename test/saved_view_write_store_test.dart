import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/saved_view_read_store.dart';
import 'package:bookmark_app/data/saved_view_write_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SavedViewWriteStore writes;
  late SavedViewReadStore reads;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    writes = SavedViewWriteStore(database);
    reads = SavedViewReadStore(database);
  });

  tearDown(() => database.close());

  test('create and update preserve Saved View fields and tag replacement',
      () async {
    final firstTag = await database.createTag('First');
    final secondTag = await database.createTag('Second');

    final id = await writes.create(
      name: 'Initial',
      layoutType: 'gallery',
      tagIds: [firstTag, firstTag],
      minRating: 9,
      statusFilter: 'unread',
    );

    var config = (await reads.watchConfigs().first).single;
    expect(config.view.id, id);
    expect(config.view.name, 'Initial');
    expect(config.view.layoutType, 'gallery');
    expect(config.view.minRating, 5);
    expect(config.view.statusFilter, 'unread');
    expect(config.tags.map((tag) => tag.id), [firstTag]);

    await writes.update(
      id: id,
      name: 'Updated',
      layoutType: 'list',
      searchQuery: 'query',
      favoritesOnly: true,
      tagIds: [secondTag],
      tagMatchMode: 'and',
      sortField: 'title',
      sortDirection: 'asc',
      visibleProperties: 'url,title',
      statusFilter: 'done',
      minRating: -2,
      includeDescendants: false,
    );

    config = (await reads.watchConfigs().first).single;
    expect(config.view.name, 'Updated');
    expect(config.view.layoutType, 'list');
    expect(config.view.searchQuery, 'query');
    expect(config.view.favoritesOnly, isTrue);
    expect(config.view.tagMatchMode, 'and');
    expect(config.view.sortField, 'title');
    expect(config.view.sortDirection, 'asc');
    expect(config.view.visibleProperties, 'url,title');
    expect(config.view.statusFilter, 'done');
    expect(config.view.minRating, 0);
    expect(config.view.includeDescendants, isFalse);
    expect(config.tags.map((tag) => tag.id), [secondTag]);
  });

  test('delete removes the Saved View and reports affected row count', () async {
    final id = await writes.create(name: 'Delete me', layoutType: 'table');

    expect(await writes.delete(id), 1);
    expect(await reads.watchConfigs().first, isEmpty);
    expect(await writes.delete(id), 0);
  });
}
