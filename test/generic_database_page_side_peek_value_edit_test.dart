import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('side peek edits a simple Value and persists it on the same Object',
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
    final notePropertyId = await objectStore.createProperty(
      objectTypeId: databaseId,
      name: 'Note',
      type: ObjectPropertyType.text,
    );
    final objectType = (await objectStore.getObjectType(databaseId))!;
    final noteProperty = objectType.properties
        .singleWhere((property) => property.id == notePropertyId);
    final objectId = await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Side edit target',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: noteProperty,
      value: 'old note',
    );

    final definition = DatabaseDefinition(
      key: 'custom:$databaseId',
      label: 'Notes',
      icon: Icons.note_outlined,
      properties: [
        DatabasePropertyDefinition(
          key: 'p:$notePropertyId',
          label: 'Note',
          type: DatabasePropertyType.text,
          icon: Icons.text_fields,
        ),
      ],
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

    await tester.tap(find.text('Side edit target').first);
    await tester.pumpAndSettle();
    expect(find.text('詳細'), findsOneWidget);
    expect(find.text('old note'), findsWidgets);

    await tester.tap(find.text('old note').last);
    await tester.pumpAndSettle();
    expect(find.text('Note'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).last, 'new note');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('new note'), findsWidgets);
    final persisted = (await objectStore.listObjects(databaseId)).single;
    expect(persisted.id, objectId);
    expect(persisted.values[notePropertyId], 'new note');
  });
}
