import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'side peek promotes the same Object to full page and preserves active View',
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
      final databaseId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Notes',
        icon: '📝',
      );
      final objectId = await objectStore.createObject(
        objectTypeId: databaseId,
        title: 'Promotion target',
      );

      final definition = DatabaseDefinition(
        key: 'custom:$databaseId',
        label: 'Notes',
        icon: Icons.note_outlined,
        properties: const <DatabasePropertyDefinition>[],
        defaultLayout: 'list',
        supportedLayouts: const <String>['list'],
      );
      final viewStore = DatabaseViewStore(database);
      await viewStore.createView(
        workspaceId: workspaceId,
        definition: definition,
        name: 'Full View',
        layoutType: 'list',
        settings: const <String, dynamic>{'openMode': 'fullPage'},
      );
      await viewStore.createView(
        workspaceId: workspaceId,
        definition: definition,
        name: 'Side View',
        layoutType: 'list',
        settings: const <String, dynamic>{'openMode': 'sidePeek'},
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

      await tester.tap(find.text('Side View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Promotion target').first);
      await tester.pumpAndSettle();

      expect(find.text('詳細'), findsOneWidget);
      expect(find.byType(ObjectInspectorPage), findsNothing);

      await tester.tap(
        find.byKey(ValueKey('side-peek-open-full-page-$objectId')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ObjectInspectorPage), findsOneWidget);

      Navigator.of(tester.element(find.byType(ObjectInspectorPage))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Side View'), findsOneWidget);
      await tester.tap(find.text('Promotion target').first);
      await tester.pumpAndSettle();

      expect(find.text('詳細'), findsOneWidget);
      expect(find.byType(ObjectInspectorPage), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    },
  );
}
