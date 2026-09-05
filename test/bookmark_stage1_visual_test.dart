import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/bookmark_unified_stage1_page.dart';
import 'package:bookmark_app/widgets/bookmark_visual_image.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Stage1 list and table use canonical bookmark visuals',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    try {
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
        url: 'https://example.com',
        title: 'Example',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookmarkUnifiedStage1Page(repository: repository),
        ),
      );

      Future<void> pumpUntil(Finder finder) async {
        for (var attempt = 0; attempt < 40; attempt++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (finder.evaluate().isNotEmpty) return;
        }
        expect(finder, findsWidgets);
      }

      await pumpUntil(find.text('Example'));

      Future<void> selectLayout(String label) async {
        await tester.tap(find.byKey(const ValueKey('database-layout-menu')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(label).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      await selectLayout('リスト');
      expect(find.byType(BookmarkVisualImage), findsOneWidget);
      var visual = tester.widget<BookmarkVisualImage>(
        find.byType(BookmarkVisualImage),
      );
      expect(visual.width, 60);
      expect(visual.height, 44);

      await selectLayout('テーブル');
      expect(find.byType(BookmarkVisualImage), findsOneWidget);
      visual = tester.widget<BookmarkVisualImage>(
        find.byType(BookmarkVisualImage),
      );
      expect(visual.width, 58);
      expect(visual.height, 38);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await database.close();
    }
  });
}
