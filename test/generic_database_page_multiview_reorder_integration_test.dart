import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'real database host reorders View tabs without changing View identities',
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
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final viewStore = DatabaseViewStore(database);

      final databaseId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'タスク',
      );
      await objectStore.createObject(
        objectTypeId: databaseId,
        title: '実装',
      );

      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: GenericDatabasePage(
            repository: repository,
            databaseId: databaseId,
            onDatabaseChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var index = 0; index < 2; index++) {
        await tester.tap(
          find.byKey(const ValueKey('database-view-create-menu')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('空のViewを作成'));
        await tester.pumpAndSettle();
      }

      final databaseKey = 'custom:$databaseId';
      final before = await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: databaseKey,
      );
      expect(before, hasLength(3));
      final originalIds = before.map((view) => view.id).toSet();

      await tester.drag(
        find.byKey(ValueKey(before.first.id)),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();

      final after = await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: databaseKey,
      );
      expect(after, hasLength(3));
      expect(after.map((view) => view.id).toSet(), originalIds);
      expect(after.map((view) => view.id).toList(), isNot(before.map((view) => view.id).toList()));

      final objects = await objectStore.listObjects(databaseId);
      expect(objects, hasLength(1));
      expect(objects.single.title, '実装');
    },
  );
}
