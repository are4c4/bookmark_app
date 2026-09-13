import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Inspector shows exact duplicate candidates and opens them', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final typeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Book',
    );
    final sourceId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Serre',
    );
    final candidateId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Serre',
    );

    await fixture.pumpInspector(tester, sourceId);

    expect(
      find.byKey(const ValueKey('object-duplicate-advisory')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('object-duplicate-candidate-$candidateId')),
      findsOneWidget,
    );
    expect(find.text('同じタイトル「Serre」'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('object-duplicate-candidate-$candidateId')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Serre'), findsWidgets);
    expect(fixture.visitedObjectIds, <int>[sourceId, candidateId]);
    expect(
      (await _objectById(fixture.objectStore, typeId, sourceId))?.title,
      'Serre',
    );
    expect(
      (await _objectById(fixture.objectStore, typeId, candidateId))?.title,
      'Serre',
    );
  });

  testWidgets('rename and alias edits refresh the advisory without mutation', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final typeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Topic',
    );
    final sourceId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Initial',
    );
    final candidateId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Shared',
    );
    await fixture.aliasStore.addAlias(
      objectId: candidateId,
      alias: 'Alias Match',
    );

    await fixture.pumpInspector(tester, sourceId);
    expect(
      find.byKey(const ValueKey('object-duplicate-advisory')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('object-title-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-title-edit-field')),
      'Shared',
    );
    await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-duplicate-candidate-$candidateId')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('object-title-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-title-edit-field')),
      'Unique',
    );
    await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('object-duplicate-advisory')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('object-alias-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-alias-add-field')),
      'Alias Match',
    );
    await tester.tap(find.byKey(const ValueKey('object-alias-add-save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-duplicate-candidate-$candidateId')),
      findsOneWidget,
    );
    expect(
      (await _objectById(fixture.objectStore, typeId, candidateId))?.title,
      'Shared',
    );
  });

  testWidgets('canonical Person participates but native system types do not', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final personBridge = PersonObjectBridge(
      database: fixture.database,
      objectStore: fixture.objectStore,
      systemObjectStore: fixture.systemObjects,
    );
    final personSchema = await personBridge.ensurePersonObjectType(
      fixture.workspaceId,
    );
    final personA = await fixture.objectStore.createObject(
      objectTypeId: personSchema.objectType.id,
      title: '同姓同名',
    );
    final personB = await fixture.objectStore.createObject(
      objectTypeId: personSchema.objectType.id,
      title: '同姓同名',
    );

    await fixture.pumpInspector(tester, personA);
    expect(
      find.byKey(ValueKey('object-duplicate-candidate-$personB')),
      findsOneWidget,
    );

    final systemType = await fixture.systemObjects.ensureSystemObjectType(
      workspaceId: fixture.workspaceId,
      systemKey: 'native-test',
      name: 'Native',
      icon: 'N',
    );
    final nativeA = await fixture.objectStore.createObject(
      objectTypeId: systemType.id,
      title: 'Duplicate Native',
    );
    await fixture.objectStore.createObject(
      objectTypeId: systemType.id,
      title: 'Duplicate Native',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await fixture.pumpInspector(tester, nativeA);

    expect(
      find.byKey(const ValueKey('object-duplicate-advisory')),
      findsNothing,
    );
  });

  testWidgets('advisory failure leaves detail usable and retry recovers', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final typeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Topic',
    );
    final sourceId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Stable Detail',
    );
    final candidateId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Stable Detail',
    );
    await fixture.aliasStore.addAlias(
      objectId: candidateId,
      alias: 'Candidate',
    );

    await fixture.pumpInspector(tester, sourceId);
    expect(find.text('Stable Detail'), findsWidgets);
    expect(
      find.byKey(ValueKey('object-duplicate-candidate-$candidateId')),
      findsOneWidget,
    );

    await fixture.database.customStatement(
      "UPDATE object_aliases SET position = 'broken' WHERE object_id = ?",
      [candidateId],
    );
    await tester.tap(find.byKey(const ValueKey('object-title-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-title-edit-field')),
      'Stable Detail',
    );
    await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('Stable Detail'), findsWidgets);
    expect(
      find.byKey(const ValueKey('object-duplicate-advisory-retry')),
      findsOneWidget,
    );

    await fixture.database.customStatement(
      'UPDATE object_aliases SET position = 0 WHERE object_id = ?',
      [candidateId],
    );
    await tester.tap(
      find.byKey(const ValueKey('object-duplicate-advisory-retry')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-duplicate-candidate-$candidateId')),
      findsOneWidget,
    );
  });
}

Future<AppObject?> _objectById(
  ObjectStore store,
  int objectTypeId,
  int objectId,
) async {
  for (final object in await store.listObjects(objectTypeId)) {
    if (object.id == objectId) return object;
  }
  return null;
}

class _Fixture {
  _Fixture({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.aliasStore,
    required this.systemObjects,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final ObjectAliasStore aliasStore;
  final SystemObjectStore systemObjects;
  final List<int> visitedObjectIds = <int>[];

  static Future<_Fixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final aliasStore = ObjectAliasStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    return _Fixture(
      database: database,
      workspaceId: workspaceId,
      genericStore: genericStore,
      objectStore: objectStore,
      aliasStore: aliasStore,
      systemObjects: systemObjects,
    );
  }

  Future<void> pumpInspector(WidgetTester tester, int objectId) async {
    visitedObjectIds.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: objectId,
          onObjectVisited: visitedObjectIds.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close() => database.close();
}
