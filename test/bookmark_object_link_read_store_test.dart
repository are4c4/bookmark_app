import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_object_link_read_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark object-link lookup stays fail-soft before mirroring and resolves after sync',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    final bookmarkId = await repository.create(
      url: 'https://example.com/read-boundary',
      title: 'Read boundary',
      inbox: true,
    );
    final store = BookmarkObjectLinkReadStore(database);

    expect(
      await store.objectIdForBookmark(
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
      ),
      isNull,
    );
    expect(
      await store.objectIdForBookmark(workspaceId: 0, bookmarkId: bookmarkId),
      isNull,
    );

    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);
    await sync.syncWorkspace(workspaceId);

    final objectId = await store.objectIdForBookmark(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    );
    expect(objectId, isNotNull);
    expect(objectId, greaterThan(0));
  });

  test('compatibility lookup failure stays fail-soft but emits a debug diagnostic',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);
    await sync.syncWorkspace(workspaceId);
    final store = BookmarkObjectLinkReadStore(database);
    await database.customStatement('DROP TABLE bookmark_object_links');

    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    expect(
      await store.objectIdForBookmark(workspaceId: workspaceId, bookmarkId: 42),
      isNull,
    );
    expect(messages, isNotEmpty);
    expect(
      messages.first,
      'Bookmark object-link compatibility lookup failed.',
    );
  });

  test('canonical Bookmark resolvers share the object-link read boundary', () {
    final urlResolver =
        File('lib/services/bookmark_url_resolver.dart').readAsStringSync();
    final visualResolver =
        File('lib/services/bookmark_visual_resolver.dart').readAsStringSync();
    final lookup =
        File('lib/data/bookmark_object_link_read_store.dart').readAsStringSync();

    expect(lookup, contains('FROM bookmark_object_links'));
    for (final source in [urlResolver, visualResolver]) {
      expect(source, contains('BookmarkObjectLinkReadStore'));
      expect(source, isNot(contains('FROM bookmark_object_links')));
      expect(source, isNot(contains('Future<int?> _bookmarkObjectId')));
    }
  });
}
