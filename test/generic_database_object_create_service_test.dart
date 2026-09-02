import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
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
}
