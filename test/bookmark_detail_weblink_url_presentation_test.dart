import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_url_resolver.dart';
import 'package:bookmark_app/widgets/bookmark_detail_panel.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Bookmark detail keeps canonical Weblink URL across presentation and edits',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await database.close();
      });
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
        url: 'https://legacy.example/stale',
        title: 'Legacy bookmark',
        inbox: true,
      );
      final bookmark = (await repository.watchAll().first)
          .singleWhere((item) => item.id == bookmarkId);

      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarkDetailPanel(
              repository: repository,
              bookmark: bookmark,
              onClose: () {},
              resolveUrl: (_) async => const BookmarkUrlSource(
                kind: BookmarkUrlSourceKind.canonicalWeblink,
                value: 'https://canonical.example/article',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('canonical.example'), findsOneWidget);
      expect(find.text('legacy.example'), findsNothing);

      await tester.tap(find.text('Legacy bookmark'));
      await tester.pump();
      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'Legacy bookmark',
      );
      expect(titleField, findsOneWidget);
      await tester.enterText(titleField, 'Renamed bookmark');
      tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 100));

      final updated = (await repository.watchAll().first)
          .singleWhere((item) => item.id == bookmarkId);
      expect(updated.title, 'Renamed bookmark');
      expect(updated.url, 'https://canonical.example/article');

      await tester.tap(find.text('canonical.example'));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.controller?.text == 'https://canonical.example/article',
        ),
        findsOneWidget,
      );
    },
  );
}
