import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late DatabaseCollectionStore collectionStore;
  late GenericDatabaseCollectionPageLoader loader;
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
    loader = GenericDatabaseCollectionPageLoader(
      genericStore: genericStore,
      collectionResolver: DatabaseCollectionResolver(
        collectionStore: collectionStore,
        objectStore: objectStore,
      ),
    );
  });

  tearDown(() => database.close());

  test('legacy page data keeps Database and self ObjectType aligned', () async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Legacy',
    );
    await objectStore.createProperty(
      objectTypeId: databaseId,
      name: 'Note',
      type: ObjectPropertyType.text,
    );
    await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'A',
    );

    final data = await loader.load(databaseId);

    expect(data, isNotNull);
    expect(data!.database.id, databaseId);
    expect(data.objectType.id, databaseId);
    expect(data.properties.single.name, 'Note');
    expect(data.records.single.title, 'A');
  });

  test('page identity stays on Database while rows come from target ObjectType',
      () async {
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

    final data = await loader.load(databaseId);

    expect(data, isNotNull);
    expect(data!.database.name, '北海道旅行');
    expect(data.database.id, databaseId);
    expect(data.objectType.name, 'Place');
    expect(data.objectType.id, placeTypeId);
    expect(data.properties.single.name, '都道府県');
    expect(data.objects.map((object) => object.title), ['札幌']);
    expect(data.records.map((record) => record.title), ['札幌']);
  });
}
