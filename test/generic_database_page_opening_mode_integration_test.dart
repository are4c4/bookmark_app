import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late WorkspaceStore workspaceStore;
  late BookmarkLifecycleStore lifecycleStore;
  late BookmarkRepository repository;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late ObjectTypeDefaultsStore defaultsStore;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceStore = WorkspaceStore(database);
    workspaceId = await workspaceStore.initialize();
    lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    defaultsStore = ObjectTypeDefaultsStore(genericStore);
  });

  tearDown(() => database.close());

  Future<void> pumpPage(WidgetTester tester, int databaseId) async {
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
  }

  DatabaseDefinition definitionFor(
    int databaseId, {
    List<DatabasePropertyDefinition> properties =
        const <DatabasePropertyDefinition>[],
  }) =>
      DatabaseDefinition(
        key: 'custom:$databaseId',
        label: 'Notes',
        icon: Icons.note_outlined,
        properties: properties,
        defaultLayout: 'list',
        supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
      );

  testWidgets('real database host uses ObjectType center-peek default',
      (tester) async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Notes',
      icon: '📝',
    );
    await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Center target',
    );
    await defaultsStore.write(
      objectTypeId: databaseId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.centerPeek),
    );
    await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: definitionFor(databaseId),
      name: 'List',
      layoutType: 'list',
    );

    await pumpPage(tester, databaseId);
    await tester.tap(find.text('Center target').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ObjectInspectorPage), findsOneWidget);
    expect(find.text('詳細'), findsNothing);

    Navigator.of(tester.element(find.byType(ObjectInspectorPage))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('real View full-page override wins over ObjectType center peek',
      (tester) async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Notes',
      icon: '📝',
    );
    await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Full target',
    );
    await defaultsStore.write(
      objectTypeId: databaseId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.centerPeek),
    );
    await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: definitionFor(databaseId),
      name: 'Gallery',
      layoutType: 'gallery',
      settings: const <String, dynamic>{'openMode': 'fullPage'},
    );

    await pumpPage(tester, databaseId);
    await tester.tap(find.text('Full target').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(ObjectInspectorPage), findsOneWidget);
    expect(find.text('詳細'), findsNothing);

    Navigator.of(tester.element(find.byType(ObjectInspectorPage))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Full target'), findsWidgets);
  });

  testWidgets('Table Object selection uses the shared opening path',
      (tester) async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Table Notes',
      icon: '🧾',
    );
    await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Table target',
    );
    await defaultsStore.write(
      objectTypeId: databaseId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.centerPeek),
    );
    await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: definitionFor(databaseId),
      name: 'Table',
      layoutType: 'table',
    );

    await pumpPage(tester, databaseId);
    await tester.tap(find.text('Table target').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ObjectInspectorPage), findsOneWidget);

    Navigator.of(tester.element(find.byType(ObjectInspectorPage))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('Board card selection uses the shared opening path',
      (tester) async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Board Notes',
      icon: '📋',
    );
    final statusId = await objectStore.createProperty(
      objectTypeId: databaseId,
      name: 'Status',
      type: ObjectPropertyType.select,
      config: const <String, dynamic>{
        'options': <String>['Todo', 'Done'],
      },
    );
    final type = (await objectStore.getObjectType(databaseId))!;
    final status = type.properties.singleWhere((property) => property.id == statusId);
    final objectId = await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Board target',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: status,
      value: 'Todo',
    );
    await defaultsStore.write(
      objectTypeId: databaseId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.centerPeek),
    );
    await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: definitionFor(
        databaseId,
        properties: <DatabasePropertyDefinition>[
          DatabasePropertyDefinition(
            key: 'p:$statusId',
            label: 'Status',
            type: DatabasePropertyType.select,
            icon: Icons.flag_outlined,
          ),
        ],
      ),
      name: 'Board',
      layoutType: 'board',
      settings: <String, dynamic>{
        'groupRule': ObjectGroupRule(propertyId: statusId).toJson(),
      },
    );

    await pumpPage(tester, databaseId);
    await tester.tap(find.text('Board target').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ObjectInspectorPage), findsOneWidget);

    Navigator.of(tester.element(find.byType(ObjectInspectorPage))).pop();
    await tester.pumpAndSettle();
  });
}
