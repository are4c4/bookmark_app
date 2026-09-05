import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_url_resolver.dart';
import 'package:bookmark_app/widgets/bookmark_reverse_lookup_dialog.dart';
import 'package:bookmark_app/widgets/bookmark_visual_image.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'reverse lookup dialog routes visual and URL through canonical presentation',
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
        url: 'https://legacy.example/stale',
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
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showBookmarkReverseLookupDialog(
                  context: context,
                  repository: repository,
                  title: 'Related bookmarks',
                  bookmarks: Stream.value([bookmark]),
                  resolveUrl: (_) async => const BookmarkUrlSource(
                    kind: BookmarkUrlSourceKind.canonicalWeblink,
                    value: 'https://canonical.example/article',
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(BookmarkVisualImage), findsOneWidget);
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('https://canonical.example/article'), findsOneWidget);
      expect(find.text('https://legacy.example/stale'), findsNothing);
    },
  );
}
