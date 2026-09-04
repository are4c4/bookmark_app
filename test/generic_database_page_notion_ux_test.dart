import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness {
  _Harness({
    required this.database,
    required this.workspaceId,
    required this.repository,
    required this.genericStore,
    required this.objectStore,
    required this.services,
  });

  final AppDatabase database;
  final int workspaceId;
  final BookmarkRepository repository;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final GenericDatabasePageServices services;

  static Future<_Harness> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
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
    return _Harness(
      database: database,
      workspaceId: workspaceId,
      repository: repository,
      genericStore: genericStore,
      objectStore: objectStore,
      services: GenericDatabasePageServices.fromStores(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
  }
}

DatabaseDefinition _definition(
  int objectTypeId,
  List<DatabasePropertyDefinition> properties, {
  String layout = 'table',
}) =>
    DatabaseDefinition(
      key: 'custom:$objectTypeId',
      label: 'Objects',
      icon: Icons.table_chart_outlined,
      properties: properties,
      defaultLayout: layout,
      supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
    );

Future<void> _pumpPage(
  WidgetTester tester,
  _Harness harness,
  int objectTypeId,
) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: GenericDatabasePage(
        repository: harness.repository,
        databaseId: objectTypeId,
        onDatabaseChanged: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {});

  testWidgets('Table renders MultiSelect and Relation as semantic chips',
      (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.database.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final personTypeId = await harness.objectStore.createObjectType(
      workspaceId: harness.workspaceId,
      name: 'Person',
      icon: '👤',
    );
    final bookTypeId = await harness.objectStore.createObjectType(
      workspaceId: harness.workspaceId,
      name: 'Book',
      icon: '📚',
    );
    final tagsId = await harness.genericStore.createProperty(
      databaseId: bookTypeId,
      name: 'Tags',
      type: 'multiSelect',
      config: const <String, dynamic>{
        'options': <String>['札幌', '旅行'],
      },
    );
    final authorPropertyId = await harness.objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final authorId = await harness.objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Canonical Author',
    );
    final bookId = await harness.objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Semantic row',
    );
    await harness.genericStore.setValue(
      recordId: bookId,
      propertyId: tagsId,
      value: const <String>['札幌', '旅行'],
    );
    final bookType = (await harness.objectStore.getObjectType(bookTypeId))!;
    final authorProperty = bookType.properties
        .singleWhere((property) => property.id == authorPropertyId);
    await harness.services.relationMutations.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: <int>[authorId],
    );

    final definition = _definition(
      bookTypeId,
      <DatabasePropertyDefinition>[
        DatabasePropertyDefinition(
          key: 'p:$tagsId',
          label: 'Tags',
          type: DatabasePropertyType.multiSelect,
          icon: Icons.sell_outlined,
        ),
        DatabasePropertyDefinition(
          key: 'p:$authorPropertyId',
          label: 'Author',
          type: DatabasePropertyType.relation,
          icon: Icons.link,
        ),
      ],
    );
    await DatabaseViewStore(harness.database).createView(
      workspaceId: harness.workspaceId,
      definition: definition,
      name: 'Table',
      layoutType: 'table',
    );

    await _pumpPage(tester, harness, bookTypeId);

    expect(find.byType(Chip), findsNWidgets(3));
    expect(find.text('札幌'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('Canonical Author'), findsOneWidget);
    expect(find.text('札幌, 旅行'), findsNothing);
    expect(find.text('$authorId'), findsNothing);
  });

  testWidgets('New page creates immediately and respects center peek opening',
      (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.database.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final typeId = await harness.objectStore.createObjectType(
      workspaceId: harness.workspaceId,
      name: 'Notes',
      icon: '📝',
    );
    final definition = _definition(
      typeId,
      const <DatabasePropertyDefinition>[],
      layout: 'list',
    );
    await DatabaseViewStore(harness.database).createView(
      workspaceId: harness.workspaceId,
      definition: definition,
      name: 'Center',
      layoutType: 'list',
      settings: const <String, dynamic>{'openMode': 'centerPeek'},
    );

    await _pumpPage(tester, harness, typeId);
    expect(await harness.genericStore.listRecords(typeId), isEmpty);

    await tester.tap(find.text('新規ページ'));
    await tester.pumpAndSettle();

    final records = await harness.genericStore.listRecords(typeId);
    expect(records, hasLength(1));
    expect(records.single.title, '新規ページ');
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('詳細'), findsNothing);
  });

  testWidgets('Table header adds Property and persists it in active View',
      (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.database.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final typeId = await harness.objectStore.createObjectType(
      workspaceId: harness.workspaceId,
      name: 'Tasks',
      icon: '✅',
    );
    final definition = _definition(typeId, const <DatabasePropertyDefinition>[]);
    await DatabaseViewStore(harness.database).createView(
      workspaceId: harness.workspaceId,
      definition: definition,
      name: 'Table',
      layoutType: 'table',
    );

    await _pumpPage(tester, harness, typeId);
    await tester.tap(find.byKey(const ValueKey<String>('table-add-property')));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final nameField =
        find.descendant(of: dialog, matching: find.byType(TextField)).first;
    await tester.enterText(nameField, 'Priority');
    await tester.tap(find.descendant(of: dialog, matching: find.text('追加')));
    await tester.pumpAndSettle();

    final properties = await harness.genericStore.listProperties(typeId);
    expect(properties.map((property) => property.name), contains('Priority'));
    final created =
        properties.singleWhere((property) => property.name == 'Priority');
    final views = await DatabaseViewStore(harness.database).listViews(
      workspaceId: harness.workspaceId,
      databaseKey: 'custom:$typeId',
    );
    expect(views.single.visibleProperties, contains('p:${created.id}'));
    expect(views.single.propertyOrder, contains('p:${created.id}'));
    expect(find.text('Priority'), findsOneWidget);
  });

  testWidgets('Table Number edit is fail-closed then persists valid value',
      (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.database.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final typeId = await harness.objectStore.createObjectType(
      workspaceId: harness.workspaceId,
      name: 'Metrics',
      icon: '📊',
    );
    final scoreId = await harness.genericStore.createProperty(
      databaseId: typeId,
      name: 'Score',
      type: 'number',
    );
    final recordId = await harness.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Metric',
    );
    await harness.genericStore.setValue(
      recordId: recordId,
      propertyId: scoreId,
      value: 5,
    );
    final definition = _definition(
      typeId,
      <DatabasePropertyDefinition>[
        DatabasePropertyDefinition(
          key: 'p:$scoreId',
          label: 'Score',
          type: DatabasePropertyType.number,
          icon: Icons.numbers,
        ),
      ],
    );
    await DatabaseViewStore(harness.database).createView(
      workspaceId: harness.workspaceId,
      definition: definition,
      name: 'Table',
      layoutType: 'table',
    );

    await _pumpPage(tester, harness, typeId);
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    var dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextFormField)),
      'invalid',
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('保存')));
    await tester.pumpAndSettle();

    var records = await harness.genericStore.listRecords(typeId);
    expect(records.single.values[scoreId], 5);
    expect(find.textContaining('数値として解釈できません'), findsOneWidget);

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextFormField)),
      '12',
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('保存')));
    await tester.pumpAndSettle();

    records = await harness.genericStore.listRecords(typeId);
    expect(records.single.values[scoreId], 12);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('Table Relation edit uses canonical Relation editor',
      (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.database.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final personTypeId = await harness.objectStore.createObjectType(
      workspaceId: harness.workspaceId,
      name: 'Person',
      icon: '👤',
    );
    final bookTypeId = await harness.objectStore.createObjectType(
      workspaceId: harness.workspaceId,
      name: 'Book',
      icon: '📚',
    );
    final authorPropertyId = await harness.objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final aliceId = await harness.objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Alice',
    );
    final bobId = await harness.objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Bob',
    );
    final bookId = await harness.objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Editable relation',
    );
    final bookType = (await harness.objectStore.getObjectType(bookTypeId))!;
    final authorProperty = bookType.properties
        .singleWhere((property) => property.id == authorPropertyId);
    await harness.services.relationMutations.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: <int>[aliceId],
    );
    final definition = _definition(
      bookTypeId,
      <DatabasePropertyDefinition>[
        DatabasePropertyDefinition(
          key: 'p:$authorPropertyId',
          label: 'Author',
          type: DatabasePropertyType.relation,
          icon: Icons.link,
        ),
      ],
    );
    await DatabaseViewStore(harness.database).createView(
      workspaceId: harness.workspaceId,
      definition: definition,
      name: 'Table',
      layoutType: 'table',
    );

    await _pumpPage(tester, harness, bookTypeId);
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    await tester.tap(find.descendant(of: dialog, matching: find.text('Bob')));
    await tester.tap(find.descendant(of: dialog, matching: find.text('保存')));
    await tester.pumpAndSettle();

    final records = await harness.genericStore.listRecords(bookTypeId);
    expect(
      ObjectRelationValue.fromJson(records.single.values[authorPropertyId])
          .objectIds,
      <int>[bobId],
    );
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('$bobId'), findsNothing);
  });
}
