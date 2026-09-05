import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_url_resolver.dart';
import 'package:bookmark_app/widgets/bookmark_visual_image.dart';
import 'package:bookmark_app/widgets/notion_bookmark_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Notion bookmark card routes image rendering through canonical visual widget',
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

    final bookmark = BookmarkItem(
      id: 1,
      url: 'https://example.com',
      title: 'Example',
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotionBookmarkCard(
            repository: repository,
            bookmark: bookmark,
            selected: false,
            showImage: true,
            showUrl: false,
            showTags: false,
            showPeople: false,
            showDescription: false,
            showCreatedAt: false,
            showFavorite: false,
            showStatus: false,
            showRating: false,
            showHistory: false,
            onTap: () {},
            onToggleFavorite: () {},
            menu: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.byType(BookmarkVisualImage), findsOneWidget);
  });

  testWidgets('Notion bookmark card displays canonical Weblink URL domain',
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
    final bookmark = BookmarkItem(
      id: -1,
      url: 'https://legacy.example/stale',
      title: 'URL migration card',
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotionBookmarkCard(
            repository: repository,
            bookmark: bookmark,
            selected: false,
            showImage: false,
            showUrl: true,
            showTags: false,
            showPeople: false,
            showDescription: false,
            showCreatedAt: false,
            showFavorite: false,
            showStatus: false,
            showRating: false,
            showHistory: false,
            onTap: () {},
            onOpen: () {},
            resolveUrl: (_) async => const BookmarkUrlSource(
              kind: BookmarkUrlSourceKind.canonicalWeblink,
              value: 'https://canonical.example/article',
            ),
            onToggleFavorite: () {},
            menu: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('canonical.example'), findsOneWidget);
    expect(find.text('legacy.example'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
