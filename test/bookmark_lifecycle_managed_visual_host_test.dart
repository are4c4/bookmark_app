import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:bookmark_app/views/bookmark_lifecycle_page.dart';
import 'package:bookmark_app/widgets/bookmark_visual_image.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('inbox list renders Bookmark visuals through canonical component',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bookmark = BookmarkItem(
      id: -1,
      url: 'https://example.com/article',
      title: 'Inbox article',
      createdAt: DateTime(2026, 9, 5),
      favorite: false,
      status: 'unread',
      rating: 0,
      openCount: 0,
      tags: const [],
      people: const [],
      photos: const [],
      collections: const [],
    );
    final repository = _StaticInboxRepository(
      database,
      items: <BookmarkItem>[bookmark],
    );

    await tester.pumpWidget(
      MaterialApp(home: BookmarkLifecyclePage.inbox(repository: repository)),
    );
    await tester.pump();

    expect(find.text('Inbox article'), findsOneWidget);
    expect(find.byType(BookmarkVisualImage), findsOneWidget);
    final visual =
        tester.widget<BookmarkVisualImage>(find.byType(BookmarkVisualImage));
    expect(visual.repository.workspaceId, 1);
    expect(visual.bookmark.title, 'Inbox article');
    expect(visual.width, 52);
    expect(visual.height, 40);
    expect(find.text('https://example.com/article'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('inbox subtitle prefers canonical Weblink URL over stale legacy URL',
      (tester) async {
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
      url: 'https://Example.com/a/../canonical?x=1',
      title: 'Canonical lifecycle article',
      inbox: true,
    );
    final sync = ObjectSyncService(database);
    await sync.syncWorkspace(workspaceId);

    await database.customStatement(
      'UPDATE bookmarks SET url = ? WHERE id = ?',
      <Object>['https://legacy.example/stale', bookmarkId],
    );

    await tester.pumpWidget(
      MaterialApp(home: BookmarkLifecyclePage.inbox(repository: repository)),
    );
    for (var attempt = 0; attempt < 30; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('https://example.com/canonical?x=1').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Canonical lifecycle article'), findsOneWidget);
    expect(find.text('https://example.com/canonical?x=1'), findsOneWidget);
    expect(find.text('https://legacy.example/stale'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await sync.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

class _StaticInboxRepository extends BookmarkRepository {
  _StaticInboxRepository(
    AppDatabase database, {
    required this.items,
  }) : super(
          database,
          workspaceStore: WorkspaceStore(database),
          lifecycleStore: BookmarkLifecycleStore(database),
          workspaceId: 1,
        );

  final List<BookmarkItem> items;

  @override
  Stream<List<BookmarkItem>> watchInbox() => Stream.value(items);
}
