import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_url_resolver.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Weblink URL wins over legacy compatibility URL', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final resolver = BookmarkUrlResolver(database: database, workspaceId: 1);

    final canonical = resolver.choosePreferred(
      canonicalWeblinkUrl: 'https://canonical.example/article',
      legacyBookmarkUrl: 'https://legacy.example/article',
    );
    expect(canonical?.kind, BookmarkUrlSourceKind.canonicalWeblink);
    expect(canonical?.value, 'https://canonical.example/article');

    final legacy = resolver.choosePreferred(
      canonicalWeblinkUrl: 'javascript:alert(1)',
      legacyBookmarkUrl: 'https://legacy.example/article',
    );
    expect(legacy?.kind, BookmarkUrlSourceKind.legacyBookmark);
    expect(legacy?.value, 'https://legacy.example/article');

    expect(
      resolver.choosePreferred(
        canonicalWeblinkUrl: 'file:///tmp/article',
        legacyBookmarkUrl: 'not a web url',
      ),
      isNull,
    );
  });

  test('resolver reads canonical Bookmark to Weblink URL before stale legacy URL',
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
      url: 'https://Example.com/a/../article?x=1',
      title: 'Article',
      inbox: true,
    );

    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);
    await sync.syncWorkspace(workspaceId);

    final resolver = BookmarkUrlResolver(
      database: database,
      workspaceId: workspaceId,
    );
    expect(
      await resolver.resolveCanonicalWeblinkUrl(bookmarkId),
      'https://example.com/article?x=1',
    );

    await database.customStatement(
      'UPDATE bookmarks SET url = ? WHERE id = ?',
      <Object>['https://legacy.example/stale', bookmarkId],
    );
    final staleBookmark = (await repository.watchInbox().first)
        .singleWhere((item) => item.id == bookmarkId);
    final resolved = await resolver.resolve(staleBookmark);

    expect(resolved?.kind, BookmarkUrlSourceKind.canonicalWeblink);
    expect(resolved?.value, 'https://example.com/article?x=1');
  });

  test('missing canonical edge falls back to legacy Bookmark URL', () async {
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
      url: 'https://example.org/legacy-only',
      title: 'Legacy only',
      inbox: true,
    );
    final bookmark = (await repository.watchInbox().first)
        .singleWhere((item) => item.id == bookmarkId);

    final resolver = BookmarkUrlResolver(
      database: database,
      workspaceId: workspaceId,
    );
    expect(await resolver.resolveCanonicalWeblinkUrl(bookmarkId), isNull);

    final resolved = await resolver.resolve(bookmark);
    expect(resolved?.kind, BookmarkUrlSourceKind.legacyBookmark);
    expect(resolved?.value, 'https://example.org/legacy-only');
  });
}
