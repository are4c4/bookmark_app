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
    'full-page edits promoted from side peek refresh the same contextual Object',
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
        title: 'Before promotion',
      );

      final definition = DatabaseDefinition(
        key: 'custom:$databaseId',
        label: 'Notes',
        icon: Icons.note_outlined,
        properties: const <DatabasePropertyDefinition>[],
        defaultLayout: 'list',
        supportedLayouts: const <String>['list'],
      );
      await DatabaseViewStore(database).createView(
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

      await tester.tap(find.text('Before promotion').first);
      await tester.pumpAndSettle();
      expect(find.text('詳細'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey('side-peek-open-full-page-$objectId')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ObjectInspectorPage), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('object-title-edit-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('object-title-edit-field')),
        'After promotion',
      );
      await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
      await tester.pumpAndSettle();
      expect(find.text('After promotion'), findsOneWidget);

      Navigator.of(tester.element(find.byType(ObjectInspectorPage))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(ObjectInspectorPage), findsNothing);
      expect(find.text('詳細'), findsOneWidget);
      expect(find.text('After promotion'), findsWidgets);

      final persisted = (await objectStore.listObjects(databaseId)).single;
      expect(persisted.id, objectId);
      expect(persisted.title, 'After promotion');
    },
  );
}
