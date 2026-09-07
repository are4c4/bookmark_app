import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/views/bookmark_unified_stage1_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bookmark Gallery switches and persists fixed/masonry mode',
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
      url: 'https://example.com/gallery-mode',
      title: 'Gallery mode bookmark',
    );

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: BookmarkUnifiedStage1Page(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gallery-mode-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('object-gallery-fixed')), findsOneWidget);
    expect(find.byKey(const ValueKey('object-gallery-masonry')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('gallery-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('メーソンリー'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('object-gallery-fixed')), findsNothing);
    expect(find.byKey(const ValueKey('object-gallery-masonry')), findsOneWidget);

    final views = await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: BuiltInDatabases.bookmarks.key,
    );
    expect(views, isNotEmpty);
    expect(views.first.settings['galleryMode'], 'masonry');

    await tester.tap(find.byKey(const ValueKey('gallery-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('固定比率'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('object-gallery-fixed')), findsOneWidget);
    expect(find.byKey(const ValueKey('object-gallery-masonry')), findsNothing);

    final fixedViews = await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: BuiltInDatabases.bookmarks.key,
    );
    expect(fixedViews.first.settings['galleryMode'], 'fixed');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
