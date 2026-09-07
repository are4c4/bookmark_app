import 'dart:async';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'watcher mirror after Search rebuild refreshes dropped Bookmark and Weblink',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final search = ObjectGlobalSearchService(genericStore);
      final refreshed = Completer<List<int>>();
      var mutationStarted = false;

      final sync = ObjectSyncService(
        database,
        onCanonicalObjectsMirrored: (objectIds) async {
          final ids = objectIds.toSet().toList()..sort();
          await search.refreshObjectLabelDependentsFor(ids);
          if (mutationStarted && !refreshed.isCompleted) {
            refreshed.complete(ids);
          }
        },
      );
      addTearDown(sync.dispose);

      // Production ordering: the live mirror is active and Global Search has
      // already rebuilt before the app-wide drop surface mutates legacy data.
      await sync.syncWorkspace(workspaceId);
      await search.rebuildWorkspace(workspaceId);
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'dropfreshobject',
        ),
        isEmpty,
      );

      mutationStarted = true;
      await database.customStatement(
        '''INSERT INTO bookmarks(url, title)
           VALUES (?, ?)''',
        <Object>[
          'local-file://drop/DropFreshObject.pdf',
          'DropFreshObject',
        ],
      );
      final bookmarkId = (await database.customSelect(
        'SELECT id FROM bookmarks ORDER BY id DESC LIMIT 1',
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        <Object>[bookmarkId, workspaceId],
      );

      final impacted = await refreshed.future.timeout(const Duration(seconds: 3));

      final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.bookmarkSystemKey,
      ))!;
      final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ))!;
      final bookmark =
          (await sync.objectStore.listObjects(bookmarkType.id)).single;
      final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;

      expect(impacted, contains(bookmark.id));
      expect(impacted, contains(weblink.id));

      final hits = await search.search(
        workspaceId: workspaceId,
        rawQuery: 'dropfreshobject',
      );
      expect(
        hits.map((hit) => hit.object.id),
        contains(bookmark.id),
        reason:
            'the debounced legacy mirror must add the canonical Bookmark FTS row while Search stays mounted',
      );
      expect(
        hits.map((hit) => hit.object.id),
        contains(weblink.id),
        reason:
            'the same focused mirror impact must add the reusable Weblink FTS row without a workspace rebuild',
      );
    },
  );

  test('canonical mirror survives a throwing Search impact callback', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final callbackStarted = Completer<void>();
    var mutationStarted = false;

    final sync = ObjectSyncService(
      database,
      onCanonicalObjectsMirrored: (_) async {
        if (!mutationStarted) return;
        if (!callbackStarted.isCompleted) callbackStarted.complete();
        throw StateError('private downstream Search failure');
      },
    );
    addTearDown(sync.dispose);

    await sync.syncWorkspace(workspaceId);
    mutationStarted = true;
    await database.customStatement(
      '''INSERT INTO bookmarks(url, title)
         VALUES (?, ?)''',
      <Object>[
        'local-file://drop/StillCanonical.pdf',
        'Still canonical after Search failure',
      ],
    );
    final bookmarkId = (await database.customSelect(
      'SELECT id FROM bookmarks ORDER BY id DESC LIMIT 1',
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );

    await callbackStarted.future.timeout(const Duration(seconds: 3));

    final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    ))!;
    final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    final bookmark =
        (await sync.objectStore.listObjects(bookmarkType.id)).single;
    final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
    final relation = bookmarkType.properties.singleWhere(
      (property) => property.name == 'Weblink',
    );

    expect(
      ObjectRelationValue.fromJson(bookmark.values[relation.id]).objectIds,
      <int>[weblink.id],
      reason:
          'downstream Search refresh failure must not roll back the completed canonical Bookmark -> Weblink mirror',
    );
  });
}
