import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late DatabaseCollectionStore collectionStore;
  late GenericDatabaseObjectCreateService service;
  late DailyNoteService dailyNotes;
  late SystemObjectStore systemObjects;
  late ObjectTypeDefaultsStore defaultsStore;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final relationMutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    defaultsStore = ObjectTypeDefaultsStore(genericStore);
    dailyNotes = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    service = GenericDatabaseObjectCreateService(
      pageLoader: GenericDatabaseCollectionPageLoader(
        genericStore: genericStore,
        collectionResolver: DatabaseCollectionResolver(
          collectionStore: collectionStore,
          objectStore: objectStore,
        ),
      ),
      objectStore: objectStore,
      boardCreate: ObjectBoardCreateService(
        objectStore,
        relationMutations: relationMutations,
      ),
      systemObjects: systemObjects,
      dailyNotes: dailyNotes,
    );
  });

  tearDown(() => database.close());

  test('creates new Object in collection target ObjectType', () async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '北海道旅行',
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

    final objectId = await service.create(
      databaseId: databaseId,
      title: '札幌市時計台',
    );

    expect((await objectStore.listObjects(placeTypeId)).single.id, objectId);
    expect(await objectStore.listObjects(databaseId), isEmpty);
  });

  test('Daily Notes collection create reuses the date-keyed today Object', () async {
    final definition = await dailyNotes.ensureDefinition(workspaceId);

    final firstId = await service.create(
      databaseId: definition.objectType.id,
      title: '新規ページ',
    );
    final secondId = await service.create(
      databaseId: definition.objectType.id,
      title: '別のタイトル',
    );

    expect(secondId, firstId);
    final created = (await objectStore.listObjects(definition.objectType.id)).single;
    final today = DateTime.now().toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final dateKey =
        '${today.year.toString().padLeft(4, '0')}-${two(today.month)}-${two(today.day)}';
    expect(created.title, dateKey);
    expect(created.values[definition.dateProperty.id], dateKey);
  });

  test('Weblinks reject generic creation that bypasses URL identity', () async {
    final definition = await WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);

    await expectLater(
      service.create(
        databaseId: definition.objectType.id,
        title: '新規ページ',
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
  });

  test('Images reject generic creation that bypasses managed file identity', () async {
    final definition = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);

    await expectLater(
      service.create(
        databaseId: definition.objectType.id,
        title: '新規ページ',
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
  });

  test('Weblinks reject generic Board creation before any group preset', () async {
    final definition = await WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);

    await expectLater(
      service.createInGroup(
        databaseId: definition.objectType.id,
        title: '新規ページ',
        groupProperty: definition.urlProperty,
        targetGroup: const ObjectGroupBucket<AppObject>(
          key: 'invalid',
          label: 'invalid',
          value: 'invalid',
          items: <AppObject>[],
          isEmptyGroup: false,
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
  });

  test('Images reject generic Board creation before any group preset', () async {
    final definition = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);

    await expectLater(
      service.createInGroup(
        databaseId: definition.objectType.id,
        title: '新規ページ',
        groupProperty: definition.noteProperty,
        targetGroup: const ObjectGroupBucket<AppObject>(
          key: 'invalid',
          label: 'invalid',
          value: 'invalid',
          items: <AppObject>[],
          isEmptyGroup: false,
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
  });

  test('createInGroup presets canonical target ObjectType Property', () async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Reading',
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    await objectStore.createProperty(
      objectTypeId: bookTypeId,
      name: 'Status',
      type: ObjectPropertyType.select,
      config: const <String, dynamic>{
        'options': <String>['未読', '読了'],
      },
    );
    final property = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    await collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: bookTypeId,
      ),
    );

    final objectId = await service.createInGroup(
      databaseId: databaseId,
      title: '数論講義',
      groupProperty: property,
      targetGroup: const ObjectGroupBucket<AppObject>(
        key: '読了',
        label: '読了',
        value: '読了',
        items: <AppObject>[],
        isEmptyGroup: false,
      ),
    );

    final created = (await objectStore.listObjects(bookTypeId))
        .singleWhere((object) => object.id == objectId);
    expect(created.values[property.id], '読了');
  });

  test('Daily Notes reject generic Board group creation', () async {
    final definition = await dailyNotes.ensureDefinition(workspaceId);

    await expectLater(
      service.createInGroup(
        databaseId: definition.objectType.id,
        title: '新規ページ',
        groupProperty: definition.dateProperty,
        targetGroup: const ObjectGroupBucket<AppObject>(
          key: 'today',
          label: 'today',
          value: 'today',
          items: <AppObject>[],
          isEmptyGroup: false,
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
  });
}
