import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/historical_database_fixtures.dart';

void main() {
  test('legacy v8 first open preserves seeded historical values', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bookmark-v8-first-open-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/database.sqlite');

    final database = AppDatabase.forTesting(
      historicalDatabaseExecutor(file, HistoricalDatabaseCheckpoint.legacyV8),
    );
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 16);

    final bookmark = await database
        .customSelect(
          'SELECT id, url, title, thumbnail, description, created_at, favorite, '
          'reading_status, storage_state, genre, deleted_at '
          'FROM bookmarks WHERE id = 7',
        )
        .getSingle();
    expect(bookmark.read<int>('id'), 7);
    expect(bookmark.read<String>('url'), 'https://fixture.invalid/article');
    expect(bookmark.read<String>('title'), 'Synthetic legacy bookmark');
    expect(
      bookmark.read<String>('thumbnail'),
      'managed/thumbnails/synthetic.jpg',
    );
    expect(bookmark.read<String>('description'), 'fixture description');
    expect(bookmark.read<int>('created_at'), 1704067200);
    expect(bookmark.read<int>('favorite'), 1);
    expect(bookmark.read<String>('reading_status'), 'unread');
    expect(bookmark.read<String>('storage_state'), 'active');
    expect(bookmark.read<String>('genre'), '');
    expect(bookmark.readNullable<int>('deleted_at'), isNull);

    final person = await database
        .customSelect('SELECT id, name, note FROM people WHERE id = 3')
        .getSingle();
    expect(person.read<int>('id'), 3);
    expect(person.read<String>('name'), 'Synthetic Person');
    expect(person.read<String>('note'), 'fixture note');

    final photo = await database
        .customSelect('SELECT id, path, title FROM photos WHERE id = 4')
        .getSingle();
    expect(photo.read<int>('id'), 4);
    expect(photo.read<String>('path'), 'managed/photos/synthetic-cover.jpg');
    expect(photo.read<String>('title'), 'Synthetic cover');

    final view = await database
        .customSelect(
          'SELECT id, name, layout_type, search_query, favorites_only, '
          'sort_field, sort_direction, visible_properties, include_descendants, '
          'person_filter_id, photo_filter_id FROM saved_views WHERE id = 5',
        )
        .getSingle();
    expect(view.read<int>('id'), 5);
    expect(view.read<String>('name'), 'Synthetic legacy view');
    expect(view.read<String>('layout_type'), 'table');
    expect(view.read<String>('search_query'), 'fixture needle');
    expect(view.read<int>('favorites_only'), 1);
    expect(view.read<String>('sort_field'), 'title');
    expect(view.read<String>('sort_direction'), 'asc');
    expect(view.read<String>('visible_properties'), 'image,url,tags');
    expect(view.read<int>('include_descendants'), 1);
    expect(view.readNullable<int>('person_filter_id'), isNull);
    expect(view.readNullable<int>('photo_filter_id'), isNull);
  });
}
