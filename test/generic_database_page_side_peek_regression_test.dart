import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real database host keeps the contextual side detail behavior',
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
      title: 'Side peek target',
    );

    final definition = DatabaseDefinition(
      key: 'custom:$databaseId',
      label: 'Notes',
      icon: Icons.table_chart_outlined,
      properties: const <DatabasePropertyDefinition>[],
      defaultLayout: 'table',
      supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
    );
    await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'List',
      layoutType: 'list',
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

    expect(find.text('詳細'), findsNothing);
    await tester.tap(find.text('Side peek target').first);
    await tester.pumpAndSettle();

    expect(find.text('詳細'), findsOneWidget);
    expect(find.text('Side peek target'), findsWidgets);
    expect(find.byType(Dialog), findsNothing);
  });
}
