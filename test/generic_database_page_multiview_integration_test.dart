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
    'real database host duplicates current View and can create a blank View',
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
        name: '読書管理',
      );
      await objectStore.createObject(
        objectTypeId: databaseId,
        title: '数論講義',
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

      final databaseKey = 'custom:$databaseId';
      var views = await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: databaseKey,
      );
      expect(views, hasLength(1));
      final original = views.single;

      await tester.tap(
        find.byKey(const ValueKey('database-view-add-button')),
      );
      await tester.pumpAndSettle();

      views = await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: databaseKey,
      );
      expect(views, hasLength(2));
      final duplicate = views.singleWhere((view) => view.id != original.id);
      expect(duplicate.databaseKey, original.databaseKey);
      expect(duplicate.layoutType, original.layoutType);
      expect(duplicate.filters, original.filters);
      expect(duplicate.sorts, original.sorts);
      expect(duplicate.settings, original.settings);
      expect(duplicate.visibleProperties, original.visibleProperties);
      expect(duplicate.propertyOrder, original.propertyOrder);

      await tester.tap(
        find.byKey(const ValueKey('database-view-create-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('空のViewを作成'));
      await tester.pumpAndSettle();

      views = await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: databaseKey,
      );
      expect(views, hasLength(3));
      final blank = views.singleWhere(
        (view) => view.id != original.id && view.id != duplicate.id,
      );
      expect(blank.name, '新しいビュー');
      expect(blank.filters, isEmpty);
      expect(blank.sorts, isEmpty);
      expect(blank.settings, isEmpty);

      final objects = await objectStore.listObjects(databaseId);
      expect(objects, hasLength(1));
      expect(objects.single.title, '数論講義');
    },
  );
}
