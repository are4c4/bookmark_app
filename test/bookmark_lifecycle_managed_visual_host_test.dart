import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
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
    await repository.create(
      url: 'https://example.com/article',
      title: 'Inbox article',
      inbox: true,
    );

    await tester.pumpWidget(
      MaterialApp(home: BookmarkLifecyclePage.inbox(repository: repository)),
    );
    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.text('Inbox article').evaluate().isNotEmpty) break;
    }

    expect(find.text('Inbox article'), findsOneWidget);
    expect(find.byType(BookmarkVisualImage), findsOneWidget);
    final visual =
        tester.widget<BookmarkVisualImage>(find.byType(BookmarkVisualImage));
    expect(visual.repository.workspaceId, workspaceId);
    expect(visual.bookmark.title, 'Inbox article');
    expect(visual.width, 52);
    expect(visual.height, 40);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
