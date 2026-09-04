import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live mirror follows tag changes after startup sync', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    await sync.syncWorkspace(workspaceId);
    await database.customStatement("INSERT INTO tags(name) VALUES ('後から追加')");

    await Future<void>.delayed(const Duration(milliseconds: 650));

    final tagType = await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'tag',
    );
    expect(tagType, isNotNull);
    final objects = await sync.objectStore.listObjects(tagType!.id);
    expect(objects.map((object) => object.title), contains('後から追加'));
  });

  test('live Bookmark mirror links repeated URLs and retires direct Object URLs',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://example.com/article', 'First')",
    );
    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://example.com/article', 'Second')",
    );
    final legacyRows = await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://example.com/article' ORDER BY id",
    ).get();
    for (final row in legacyRows) {
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        [row.read<int>('id'), workspaceId],
      );
    }

    await sync.syncWorkspace(workspaceId);

    final bookmarkType = await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    );
    final weblinkType = await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    expect(bookmarkType, isNotNull);
    expect(weblinkType, isNotNull);

    final relation = bookmarkType!.properties.singleWhere(
      (property) => property.name == 'Weblink',
    );
    expect(relation.isRelation, isTrue);
    expect(relation.targetObjectTypeId, weblinkType!.id);
    expect(relation.allowsMultipleRelations, isFalse);

    final bookmarks = await sync.objectStore.listObjects(bookmarkType.id);
    final weblinks = await sync.objectStore.listObjects(weblinkType.id);
    expect(bookmarks, hasLength(2));
    expect(weblinks, hasLength(1));
    final targetId = weblinks.single.id;
    for (final bookmark in bookmarks) {
      expect(
        ObjectRelationValue.fromJson(bookmark.values[relation.id]).objectIds,
        <int>[targetId],
      );
      final edges = await sync.objectStore.outgoingRelations(bookmark.id);
      expect(edges.where((edge) => edge.propertyId == relation.id), hasLength(1));
      expect(
        edges.singleWhere((edge) => edge.propertyId == relation.id).targetObjectId,
        targetId,
      );
    }

    final directUrl = bookmarkType.properties.singleWhere(
      (property) => property.name == 'URL',
    );
    for (final bookmark in bookmarks) {
      expect(bookmark.values[directUrl.id], isNull);
    }
    final preservedLegacyUrls = await database.customSelect(
      'SELECT url FROM bookmarks ORDER BY id',
    ).get();
    expect(
      preservedLegacyUrls.map((row) => row.read<String>('url')).toList(),
      <String>['https://example.com/article', 'https://example.com/article'],
    );

    await sync.syncWorkspace(workspaceId);

    expect(await sync.objectStore.listObjects(weblinkType.id), hasLength(1));
    final refreshedBookmarks = await sync.objectStore.listObjects(bookmarkType.id);
    for (final bookmark in refreshedBookmarks) {
      expect(bookmark.values[directUrl.id], isNull);
      final edges = await sync.objectStore.outgoingRelations(bookmark.id);
      expect(edges.where((edge) => edge.propertyId == relation.id), hasLength(1));
    }

    final report = await sync.bookmarkWeblinkBridge.syncWorkspace(workspaceId);
    expect(report.processedCount, 2);
    expect(report.linkedCount, 2);
    expect(report.invalidUrlCount, 0);
    expect(report.retiredLegacyUrlCount, 2);
  });

  test('invalid legacy URL is preserved and does not get a Weblink Relation',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('not a URL', 'Broken')",
    );
    final legacyId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE title = 'Broken'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      [legacyId, workspaceId],
    );

    await sync.syncWorkspace(workspaceId);

    final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    ))!;
    final relation = bookmarkType.properties.singleWhere(
      (property) => property.name == 'Weblink',
    );
    final directUrl = bookmarkType.properties.singleWhere(
      (property) => property.name == 'URL',
    );
    final bookmark = (await sync.objectStore.listObjects(bookmarkType.id)).single;
    expect(
      ObjectRelationValue.fromJson(bookmark.values[relation.id]).objectIds,
      isEmpty,
    );
    expect(bookmark.values[directUrl.id], 'not a URL');

    final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    expect(await sync.objectStore.listObjects(weblinkType.id), isEmpty);

    final report = await sync.bookmarkWeblinkBridge.syncWorkspace(workspaceId);
    expect(report.processedCount, 1);
    expect(report.linkedCount, 0);
    expect(report.invalidUrlCount, 1);
    expect(report.retiredLegacyUrlCount, 0);
  });

  test('activating another workspace replaces the previous live mirror', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaces = WorkspaceStore(database);
    final first = await workspaces.initialize();
    final second = await workspaces.createWorkspace('Second');
    final firstSync = ObjectSyncService(database);
    final secondSync = ObjectSyncService(database);
    addTearDown(firstSync.dispose);
    addTearDown(secondSync.dispose);

    await firstSync.syncWorkspace(first);
    await secondSync.syncWorkspace(second);
    await database.customStatement("INSERT INTO tags(name) VALUES ('共有タグ')");
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final firstTagType = await firstSync.systemObjectStore.getSystemObjectType(
      workspaceId: first,
      systemKey: 'tag',
    );
    final secondTagType = await secondSync.systemObjectStore.getSystemObjectType(
      workspaceId: second,
      systemKey: 'tag',
    );
    final firstObjects = await firstSync.objectStore.listObjects(firstTagType!.id);
    final secondObjects = await secondSync.objectStore.listObjects(secondTagType!.id);

    expect(firstObjects.map((object) => object.title), isNot(contains('共有タグ')));
    expect(secondObjects.map((object) => object.title), contains('共有タグ'));
  });
}
