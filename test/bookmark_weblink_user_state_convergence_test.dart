import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> expectSavedStateConflict({
    bool favorite = false,
    String readingStatus = 'unread',
    String storageState = 'active',
    String genre = '',
    int rating = 0,
  }) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    await database.customStatement(
      'INSERT INTO bookmarks('
      'url, title, favorite, reading_status, storage_state, genre, rating'
      ') VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object>[
        'https://example.com/article',
        'First',
        0,
        'unread',
        'active',
        '',
        0,
      ],
    );
    await database.customStatement(
      'INSERT INTO bookmarks('
      'url, title, favorite, reading_status, storage_state, genre, rating'
      ') VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object>[
        'https://example.com/article',
        'Second',
        favorite ? 1 : 0,
        readingStatus,
        storageState,
        genre,
        rating,
      ],
    );
    final legacyRows = await database
        .customSelect('SELECT id FROM bookmarks ORDER BY id')
        .get();
    for (final row in legacyRows) {
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) '
        'VALUES (?, ?)',
        <Object>[row.read<int>('id'), workspaceId],
      );
    }

    await sync.coreBridge.syncAll(workspaceId);

    await expectLater(
      sync.bookmarkWeblinkBridge.syncWorkspace(workspaceId),
      throwsA(isA<StateError>()),
    );

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
    final bookmarks = await sync.objectStore.listObjects(bookmarkType.id);
    expect(bookmarks, hasLength(2));
    for (final bookmark in bookmarks) {
      expect(
        ObjectRelationValue.fromJson(bookmark.values[relation.id]).objectIds,
        isEmpty,
      );
      expect(bookmark.values[directUrl.id], 'https://example.com/article');
      final edges = await sync.objectStore.outgoingRelations(bookmark.id);
      expect(edges.where((edge) => edge.propertyId == relation.id), isEmpty);
    }

    final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    expect(await sync.objectStore.listObjects(weblinkType.id), hasLength(1));

    final preservedLegacy = await database
        .customSelect('SELECT url FROM bookmarks ORDER BY id')
        .get();
    expect(
      preservedLegacy.map((row) => row.read<String>('url')).toList(),
      <String>['https://example.com/article', 'https://example.com/article'],
    );
  }

  test(
    'Favorite conflict fails before Bookmark Relation or URL retirement',
    () async {
      await expectSavedStateConflict(favorite: true);
    },
  );

  test(
    'Reading Status conflict fails before Bookmark Relation or URL retirement',
    () async {
      await expectSavedStateConflict(readingStatus: 'done');
    },
  );

  test(
    'Storage State conflict fails before Bookmark Relation or URL retirement',
    () async {
      await expectSavedStateConflict(storageState: 'archived');
    },
  );

  test(
    'Genre conflict fails before Bookmark Relation or URL retirement',
    () async {
      await expectSavedStateConflict(genre: 'Research');
    },
  );

  test(
    'Rating conflict fails before Bookmark Relation or URL retirement',
    () async {
      await expectSavedStateConflict(rating: 5);
    },
  );

  test(
    'preserved conflict can reconcile after restart without duplicate Weblink',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();

      await database.customStatement(
        'INSERT INTO bookmarks(url, title, favorite) VALUES (?, ?, ?)',
        <Object>['https://example.com/article', 'First', 0],
      );
      await database.customStatement(
        'INSERT INTO bookmarks(url, title, favorite) VALUES (?, ?, ?)',
        <Object>['https://example.com/article', 'Second', 1],
      );
      final legacyRows = await database
          .customSelect('SELECT id FROM bookmarks ORDER BY id')
          .get();
      for (final row in legacyRows) {
        await database.customStatement(
          'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) '
          'VALUES (?, ?)',
          <Object>[row.read<int>('id'), workspaceId],
        );
      }

      final firstSync = ObjectSyncService(database);
      await firstSync.coreBridge.syncAll(workspaceId);
      await expectLater(
        firstSync.bookmarkWeblinkBridge.syncWorkspace(workspaceId),
        throwsA(isA<StateError>()),
      );
      final firstWeblinkType = (await firstSync.systemObjectStore
          .getSystemObjectType(
            workspaceId: workspaceId,
            systemKey: WeblinkObjectService.systemKey,
          ))!;
      expect(
        await firstSync.objectStore.listObjects(firstWeblinkType.id),
        hasLength(1),
      );
      await firstSync.dispose();

      final secondLegacyId = legacyRows[1].read<int>('id');
      await database.customStatement(
        'UPDATE bookmarks SET favorite = 0 WHERE id = ?',
        <Object>[secondLegacyId],
      );

      final restarted = ObjectSyncService(database);
      addTearDown(restarted.dispose);
      await restarted.coreBridge.syncAll(workspaceId);
      final report = await restarted.bookmarkWeblinkBridge.syncWorkspace(
        workspaceId,
      );

      expect(report.processedCount, 2);
      expect(report.linkedCount, 2);
      expect(report.invalidUrlCount, 0);
      expect(report.retiredLegacyUrlCount, 2);

      final bookmarkType = (await restarted.systemObjectStore
          .getSystemObjectType(
            workspaceId: workspaceId,
            systemKey: CoreObjectBridge.bookmarkSystemKey,
          ))!;
      final relation = bookmarkType.properties.singleWhere(
        (property) => property.name == 'Weblink',
      );
      final directUrl = bookmarkType.properties.singleWhere(
        (property) => property.name == 'URL',
      );
      final weblinkType = (await restarted.systemObjectStore
          .getSystemObjectType(
            workspaceId: workspaceId,
            systemKey: WeblinkObjectService.systemKey,
          ))!;
      final weblinks = await restarted.objectStore.listObjects(weblinkType.id);
      expect(weblinks, hasLength(1));
      final targetId = weblinks.single.id;

      final bookmarks = await restarted.objectStore.listObjects(
        bookmarkType.id,
      );
      expect(bookmarks, hasLength(2));
      for (final bookmark in bookmarks) {
        expect(
          ObjectRelationValue.fromJson(bookmark.values[relation.id]).objectIds,
          <int>[targetId],
        );
        expect(bookmark.values[directUrl.id], isNull);
        final edges = await restarted.objectStore.outgoingRelations(
          bookmark.id,
        );
        final weblinkEdges = edges
            .where((edge) => edge.propertyId == relation.id)
            .toList();
        expect(weblinkEdges, hasLength(1));
        expect(weblinkEdges.single.targetObjectId, targetId);
      }
    },
  );
}
