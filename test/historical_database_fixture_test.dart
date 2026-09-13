import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/historical_database_fixtures.dart';

void main() {
  group('historical database fixtures', () {
    test('legacy v8 migrates losslessly and reopening is idempotent', () async {
      final directory = await Directory.systemTemp.createTemp('bookmark-v8-fixture-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');

      final first = AppDatabase.forTesting(
        historicalDatabaseExecutor(file, HistoricalDatabaseCheckpoint.legacyV8),
      );
      await first.customSelect('SELECT 1').get();
      final firstSnapshot = await _legacyV8Snapshot(first);
      _expectLegacyV8(firstSnapshot, checkpoint: 'legacy-v8 first open');
      await first.close();

      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      await reopened.customSelect('SELECT 1').get();
      final secondSnapshot = await _legacyV8Snapshot(reopened);
      _expectLegacyV8(secondSnapshot, checkpoint: 'legacy-v8 reopen');
      expect(
        secondSnapshot,
        firstSnapshot,
        reason: 'legacy-v8 logical state changed after an already-migrated reopen',
      );
      await reopened.close();
    });

    test('object-era v16 preserves Object Body Relation and View state', () async {
      final directory = await Directory.systemTemp.createTemp('bookmark-v16-fixture-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');

      final first = AppDatabase.forTesting(
        historicalDatabaseExecutor(
          file,
          HistoricalDatabaseCheckpoint.objectEraV16,
        ),
      );
      await first.customSelect('SELECT 1').get();
      final firstSnapshot = await _objectEraSnapshot(first);
      _expectObjectEra(firstSnapshot, checkpoint: 'object-era-v16 first open');
      await first.close();

      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      await reopened.customSelect('SELECT 1').get();
      final secondSnapshot = await _objectEraSnapshot(reopened);
      _expectObjectEra(secondSnapshot, checkpoint: 'object-era-v16 reopen');
      expect(
        secondSnapshot,
        firstSnapshot,
        reason: 'object-era-v16 logical state changed after restart',
      );
      await reopened.close();
    });
  });
}

Future<Map<String, Object?>> _legacyV8Snapshot(AppDatabase database) async {
  final version = await database.customSelect('PRAGMA user_version').getSingle();
  final bookmark = await database.customSelect(
    'SELECT id, url, title, thumbnail, description, created_at, favorite, '
    'reading_status, storage_state, genre, deleted_at FROM bookmarks WHERE id = 7',
  ).getSingle();
  final person = await database.customSelect(
    'SELECT id, name, note FROM people WHERE id = 3',
  ).getSingle();
  final role = await database.customSelect(
    'SELECT role FROM bookmark_people WHERE bookmark_id = 7 AND person_id = 3',
  ).getSingle();
  final photo = await database.customSelect(
    'SELECT p.id, p.path, p.title, bp.is_cover FROM photos p '
    'JOIN bookmark_photos bp ON bp.photo_id = p.id '
    'WHERE bp.bookmark_id = 7',
  ).getSingle();
  final view = await database.customSelect(
    'SELECT id, name, layout_type, search_query, favorites_only, sort_field, '
    'sort_direction, visible_properties, include_descendants, person_filter_id, '
    'photo_filter_id FROM saved_views WHERE id = 5',
  ).getSingle();

  return <String, Object?>{
    'version': version.read<int>('user_version'),
    'bookmark': <String, Object?>{
      'id': bookmark.read<int>('id'),
      'url': bookmark.read<String>('url'),
      'title': bookmark.read<String>('title'),
      'thumbnail': bookmark.read<String>('thumbnail'),
      'description': bookmark.read<String>('description'),
      'createdAt': bookmark.read<int>('created_at'),
      'favorite': bookmark.read<int>('favorite'),
      'readingStatus': bookmark.read<String>('reading_status'),
      'storageState': bookmark.read<String>('storage_state'),
      'genre': bookmark.read<String>('genre'),
      'deletedAt': bookmark.readNullable<int>('deleted_at'),
    },
    'person': <String, Object?>{
      'id': person.read<int>('id'),
      'name': person.read<String>('name'),
      'note': person.read<String>('note'),
      'role': role.read<String>('role'),
    },
    'photo': <String, Object?>{
      'id': photo.read<int>('id'),
      'path': photo.read<String>('path'),
      'title': photo.read<String>('title'),
      'isCover': photo.read<int>('is_cover'),
    },
    'view': <String, Object?>{
      'id': view.read<int>('id'),
      'name': view.read<String>('name'),
      'layout': view.read<String>('layout_type'),
      'query': view.read<String>('search_query'),
      'favoritesOnly': view.read<int>('favorites_only'),
      'sortField': view.read<String>('sort_field'),
      'sortDirection': view.read<String>('sort_direction'),
      'visibleProperties': view.read<String>('visible_properties'),
      'includeDescendants': view.read<int>('include_descendants'),
      'personFilterId': view.readNullable<int>('person_filter_id'),
      'photoFilterId': view.readNullable<int>('photo_filter_id'),
    },
  };
}

void _expectLegacyV8(
  Map<String, Object?> snapshot, {
  required String checkpoint,
}) {
  expect(snapshot['version'], 16, reason: '$checkpoint did not reach current schema');
  final bookmark = snapshot['bookmark']! as Map<String, Object?>;
  expect(bookmark['url'], 'https://fixture.invalid/article', reason: '$checkpoint lost Bookmark URL');
  expect(bookmark['title'], 'Synthetic legacy bookmark', reason: '$checkpoint lost Bookmark title');
  expect(bookmark['thumbnail'], 'managed/thumbnails/synthetic.jpg', reason: '$checkpoint lost media reference');
  expect(bookmark['createdAt'], 1704067200, reason: '$checkpoint changed creation time');
  expect(bookmark['readingStatus'], 'unread', reason: '$checkpoint changed reading lifecycle');
  expect(bookmark['storageState'], 'active', reason: '$checkpoint changed storage lifecycle');

  final person = snapshot['person']! as Map<String, Object?>;
  expect(person['name'], 'Synthetic Person', reason: '$checkpoint lost Person identity');
  expect(person['role'], '出演者', reason: '$checkpoint lost/mis-migrated Bookmark-Person relation');

  final photo = snapshot['photo']! as Map<String, Object?>;
  expect(photo['path'], 'managed/photos/synthetic-cover.jpg', reason: '$checkpoint lost Photo path');
  expect(photo['isCover'], 1, reason: '$checkpoint lost Bookmark-Photo cover relation');

  final view = snapshot['view']! as Map<String, Object?>;
  expect(view['name'], 'Synthetic legacy view', reason: '$checkpoint lost Saved View');
  expect(view['layout'], 'table', reason: '$checkpoint changed Saved View layout');
  expect(view['query'], 'fixture needle', reason: '$checkpoint changed Saved View query');
  expect(view['visibleProperties'], 'image,url,tags', reason: '$checkpoint changed Saved View properties');
}

Future<Map<String, Object?>> _objectEraSnapshot(AppDatabase database) async {
  final version = await database.customSelect('PRAGMA user_version').getSingle();
  final genericStore = GenericDatabaseStore(database);
  final objectStore = ObjectStore(genericStore);
  final projectType = await objectStore.getObjectType(21);
  final project = (await objectStore.listObjects(21)).singleWhere(
    (object) => object.id == 100,
  );
  final body = await ObjectBodyStore(genericStore).read(100);
  final edges = await objectStore.outgoingRelations(100);
  final view = await database.customSelect(
    'SELECT id, database_key, name, layout_type, filters_json, sorts_json, '
    'visible_properties, property_order, settings_json FROM database_views WHERE id = 40',
  ).getSingle();

  return <String, Object?>{
    'version': version.read<int>('user_version'),
    'objectType': <String, Object?>{
      'id': projectType?.id,
      'name': projectType?.name,
      'relationProperty': projectType?.properties.singleWhere((property) => property.id == 30).name,
      'relationTargetType': projectType?.properties.singleWhere((property) => property.id == 30).targetObjectTypeId,
    },
    'object': <String, Object?>{
      'id': project.id,
      'title': project.title,
      'createdAt': project.createdAt.toUtc().toIso8601String(),
      'updatedAt': project.updatedAt.toUtc().toIso8601String(),
      'members': ObjectRelationValue.fromJson(project.values[30]).objectIds,
    },
    'body': body.blocks
        .map((block) => <String, Object?>{'id': block.id, 'type': block.type, 'text': block.text})
        .toList(growable: false),
    'edges': edges
        .map((edge) => <String, Object?>{
              'source': edge.sourceObjectId,
              'property': edge.propertyId,
              'target': edge.targetObjectId,
              'position': edge.position,
            })
        .toList(growable: false),
    'view': <String, Object?>{
      'id': view.read<int>('id'),
      'databaseKey': view.read<String>('database_key'),
      'name': view.read<String>('name'),
      'layout': view.read<String>('layout_type'),
      'filters': view.read<String>('filters_json'),
      'sorts': view.read<String>('sorts_json'),
      'visibleProperties': view.read<String>('visible_properties'),
      'propertyOrder': view.read<String>('property_order'),
      'settings': view.read<String>('settings_json'),
    },
  };
}

void _expectObjectEra(
  Map<String, Object?> snapshot, {
  required String checkpoint,
}) {
  expect(snapshot['version'], 16, reason: '$checkpoint changed schema version');
  final type = snapshot['objectType']! as Map<String, Object?>;
  expect(type['name'], 'Project', reason: '$checkpoint lost ObjectType identity');
  expect(type['relationProperty'], 'Members', reason: '$checkpoint lost Relation property');
  expect(type['relationTargetType'], 20, reason: '$checkpoint changed Relation target type');

  final object = snapshot['object']! as Map<String, Object?>;
  expect(object['title'], 'Synthetic Project', reason: '$checkpoint lost Object identity');
  expect(object['members'], <int>[101, 102], reason: '$checkpoint changed Relation serialized order');

  final body = snapshot['body']! as List<Map<String, Object?>>;
  expect(body.map((block) => block['id']).toList(), <String>['p-1', 'p-2'], reason: '$checkpoint changed Body order');
  expect(body.map((block) => block['text']).toList(), <String>['First fixture block', 'Second fixture block'], reason: '$checkpoint lost Body content');

  final edges = snapshot['edges']! as List<Map<String, Object?>>;
  expect(edges.map((edge) => edge['target']).toList(), <int>[101, 102], reason: '$checkpoint changed Relation edge targets/order');
  expect(edges.map((edge) => edge['position']).toList(), <int>[0, 1], reason: '$checkpoint changed Relation edge positions');

  final view = snapshot['view']! as Map<String, Object?>;
  expect(view['databaseKey'], 'custom:21', reason: '$checkpoint detached Database View');
  expect(view['layout'], 'table', reason: '$checkpoint changed Database View layout');
  expect(view['visibleProperties'], 'title,Members', reason: '$checkpoint changed View properties');
}
