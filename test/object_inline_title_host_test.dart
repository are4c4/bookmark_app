import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpUntilVisible(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 60; attempt += 1) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  testWidgets('full-page Inspector renames a custom Object inline', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Before',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: store,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );

    final editor = find.byKey(ValueKey('object-title-inline-editor-$objectId'));
    await pumpUntilVisible(tester, editor);
    expect(
      find.byKey(const ValueKey('object-title-edit-button')),
      findsNothing,
    );
    expect(find.text('Object名を変更'), findsNothing);

    final field = find.descendant(
      of: editor,
      matching: find.byKey(const ValueKey('object-inline-title-field')),
    );
    await tester.tap(field);
    await tester.enterText(field, 'After');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await pumpUntilVisible(tester, find.text('After'));

    final reloaded = (await objectStore.listObjects(objectTypeId)).single;
    expect(reloaded.title, 'After');
  });

  testWidgets('full-page save failure restores the last canonical title', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Before',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: store,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );

    final editor = find.byKey(ValueKey('object-title-inline-editor-$objectId'));
    await pumpUntilVisible(tester, editor);
    final field = find.descendant(
      of: editor,
      matching: find.byKey(const ValueKey('object-inline-title-field')),
    );

    await objectStore.deleteObject(objectId);
    await tester.tap(field);
    await tester.enterText(field, 'After');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    final errorMessage = find.text('Object名を変更できませんでした。');
    await pumpUntilVisible(tester, errorMessage);
    await tester.pump();

    expect(errorMessage, findsOneWidget);
    expect(tester.widget<TextField>(field).controller?.text, 'Before');
    expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse);
  });

  testWidgets('non-editable system Object title stays read-only', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final objectType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'readOnlyFixture',
      name: 'Read only fixture',
      icon: '🔒',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectType.id,
      title: 'Locked title',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: store,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );

    final readOnly = find.byKey(ValueKey('object-title-read-only-$objectId'));
    await pumpUntilVisible(tester, readOnly);

    expect(readOnly, findsOneWidget);
    expect(
      find.byKey(ValueKey('object-title-inline-editor-$objectId')),
      findsNothing,
    );
    expect(find.text('Locked title'), findsOneWidget);
  });

  testWidgets('Side Peek uses the shared inline title editor and persists', (
    tester,
  ) async {
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
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Notes',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Before',
    );

    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: GenericDatabasePage(
          repository: repository,
          databaseId: objectTypeId,
          onDatabaseChanged: () {},
        ),
      ),
    );

    await pumpUntilVisible(tester, find.text('Before'));
    await tester.tap(find.text('Before').first);
    await tester.pump();

    final editor = find.byKey(ValueKey('side-peek-title-editor-$objectId'));
    await pumpUntilVisible(tester, editor);

    final field = find.descendant(
      of: editor,
      matching: find.byKey(const ValueKey('object-inline-title-field')),
    );
    await tester.tap(field);
    await tester.enterText(field, 'After');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    for (var attempt = 0; attempt < 40; attempt += 1) {
      final object = (await objectStore.listObjects(objectTypeId)).single;
      if (object.title == 'After') break;
      await tester.pump(const Duration(milliseconds: 50));
    }

    final reloaded = (await objectStore.listObjects(objectTypeId)).single;
    expect(reloaded.title, 'After');
    expect(find.byType(ObjectInspectorPage), findsNothing);
  });
}
