import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('full-page Object return preserves the originating active View',
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
    await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Context target',
    );
    await ObjectTypeDefaultsStore(genericStore).write(
      objectTypeId: databaseId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.centerPeek),
    );

    final definition = DatabaseDefinition(
      key: 'custom:$databaseId',
      label: 'Notes',
      icon: Icons.note_outlined,
      properties: const <DatabasePropertyDefinition>[],
      defaultLayout: 'list',
      supportedLayouts: const <String>['gallery', 'list'],
    );
    final viewStore = DatabaseViewStore(database);
    await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'List',
      layoutType: 'list',
    );
    await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Focused Gallery',
      layoutType: 'gallery',
      settings: const <String, dynamic>{'openMode': 'fullPage'},
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

    await tester.tap(find.text('Focused Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Context target').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(ObjectInspectorPage), findsOneWidget);

    Navigator.of(tester.element(find.byType(ObjectInspectorPage))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Focused Gallery'), findsOneWidget);
    await tester.tap(find.text('Context target').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(ObjectInspectorPage), findsOneWidget);
  });
}
