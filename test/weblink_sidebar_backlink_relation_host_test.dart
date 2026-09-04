import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'exposed Weblinks host shows canonical Bookmark backlinks',
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
      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);

      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES ('https://example.com/article', 'Saved article')",
      );
      final legacyId = (await database.customSelect(
        "SELECT id FROM bookmarks WHERE title = 'Saved article'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        <Object?>[legacyId, workspaceId],
      );
      await sync.syncWorkspace(workspaceId);

      final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ))!;
      final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
      final navigation = await GenericDatabaseStore(database).listDatabases(workspaceId);
      final destination = navigation.singleWhere(
        (database) => database.id == weblinkType.id,
      );
      expect(destination.name, 'Weblinks');

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: GenericDatabasePage(
            repository: repository,
            databaseId: destination.id,
            onDatabaseChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(weblink.title).first);
      await tester.pumpAndSettle();

      expect(find.text('Backlinks  1'), findsOneWidget);
      expect(find.text('Saved article'), findsOneWidget);
      expect(find.textContaining('Weblink'), findsWidgets);
    },
  );
}
