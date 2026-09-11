import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('generic Inspector edits legacy-backed Person title and Note', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    final personId = await PersonObjectWriteService.forDatabase(database).create(
      workspaceId: workspaceId,
      name: 'Before',
      note: 'old note',
    );
    final schema = await bridge.ensurePersonObjectType(workspaceId);
    final objectId = (await bridge.objectIdForLegacyPerson(
      workspaceId,
      personId,
    ))!;

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('object-title-edit-button')),
      findsOneWidget,
    );
    final noteEdit = find.byKey(
      ValueKey('edit-object-value-${schema.noteProperty.id}'),
    );
    expect(noteEdit, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object-title-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-title-edit-field')),
      'After',
    );
    await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(noteEdit);
    await tester.tap(noteEdit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ValueKey('object-value-edit-field-${schema.noteProperty.id}')),
      'new note',
    );
    await tester.tap(
      find.byKey(ValueKey('object-value-edit-save-${schema.noteProperty.id}')),
    );
    await tester.pumpAndSettle();

    final object = (await objectStore.listObjects(schema.objectType.id)).single;
    final person = (await database.select(database.people).get()).single;
    expect(object.title, 'After');
    expect(object.values[schema.noteProperty.id], 'new note');
    expect(person.name, 'After');
    expect(person.note, 'new note');
  });

  testWidgets('generic Person Inspector hides persistence errors and fails closed', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    final personId = await PersonObjectWriteService.forDatabase(database).create(
      workspaceId: workspaceId,
      name: 'Preserved',
      note: 'old note',
    );
    final schema = await bridge.ensurePersonObjectType(workspaceId);
    final objectId = (await bridge.objectIdForLegacyPerson(
      workspaceId,
      personId,
    ))!;

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await database.customStatement(
      'DELETE FROM person_object_links WHERE workspace_id = ? AND person_id = ?',
      <Object>[workspaceId, personId],
    );

    await tester.tap(find.byKey(const ValueKey('object-title-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-title-edit-field')),
      'Must not commit',
    );
    await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('人物を更新できませんでした。'), findsOneWidget);
    final object = (await objectStore.listObjects(schema.objectType.id)).single;
    final person = (await database.select(database.people).get()).single;
    expect(object.title, 'Preserved');
    expect(object.values[schema.noteProperty.id], 'old note');
    expect(person.name, 'Preserved');
    expect(person.note, 'old note');
  });
}
