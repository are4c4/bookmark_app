import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
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
  late DatabaseCollectionStore collectionStore;
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
    collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
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

  testWidgets('real page applies Database collection before View projection',
      (tester) async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '北海道旅行',
    );
    final placeTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Place',
    );
    final prefectureId = await objectStore.createProperty(
      objectTypeId: placeTypeId,
      name: '都道府県',
      type: ObjectPropertyType.text,
    );
    final placeType = (await objectStore.getObjectType(placeTypeId))!;
    final prefecture = placeType.properties.singleWhere(
      (property) => property.id == prefectureId,
    );
    final sapporoId = await objectStore.createObject(
      objectTypeId: placeTypeId,
      title: '札幌',
    );
    final takasakiId = await objectStore.createObject(
      objectTypeId: placeTypeId,
      title: '高崎',
    );
    await objectStore.setPropertyValue(
      objectId: sapporoId,
      property: prefecture,
      value: '北海道',
    );
    await objectStore.setPropertyValue(
      objectId: takasakiId,
      property: prefecture,
      value: '群馬県',
    );
    await collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: placeTypeId,
        collectionFilter: <ObjectFilterRule>[
          ObjectFilterRule(
            propertyId: prefectureId,
            operator: ObjectFilterOperator.equals,
            value: '北海道',
          ),
        ],
      ),
    );

    await pumpPage(tester, databaseId);

    expect(find.text('北海道旅行'), findsWidgets);
    expect(find.text('札幌'), findsOneWidget);
    expect(find.text('高崎'), findsNothing);
    expect(find.text('都道府県'), findsWidgets);
  });

  testWidgets('real page creates Object in configured target ObjectType',
      (tester) async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '旅行候補',
    );
    final placeTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Place',
    );
    await collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: placeTypeId,
      ),
    );

    await pumpPage(tester, databaseId);
    await tester.tap(find.text('新規ページ').last);
    await tester.pumpAndSettle();
    final createField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '名前を入力して Enter',
    );
    expect(createField, findsOneWidget);
    await tester.enterText(createField, '小樽');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final targetObjects = await objectStore.listObjects(placeTypeId);
    expect(targetObjects.map((object) => object.title), contains('小樽'));
    expect(await objectStore.listObjects(databaseId), isEmpty);
    expect(find.text('小樽'), findsOneWidget);
  });
}
