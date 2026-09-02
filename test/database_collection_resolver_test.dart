import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
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
  late DatabaseCollectionResolver resolver;
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
    resolver = DatabaseCollectionResolver(
      collectionStore: collectionStore,
      objectStore: objectStore,
    );
  });

  tearDown(() => database.close());

  test('legacy Database resolves all Objects from its own ObjectType', () async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Legacy',
    );
    await objectStore.createObject(objectTypeId: databaseId, title: 'A');
    await objectStore.createObject(objectTypeId: databaseId, title: 'B');

    final collection = await resolver.resolve(databaseId);

    expect(collection?.definition.isLegacyFallback, isTrue);
    expect(collection?.objectType.id, databaseId);
    expect(collection?.objects.map((object) => object.title), ['B', 'A']);
  });

  test('collection filter narrows target ObjectType before View projection',
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
    final property = (await objectStore.getObjectType(placeTypeId))!
        .properties
        .singleWhere((item) => item.id == prefectureId);

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
      property: property,
      value: '北海道',
    );
    await objectStore.setPropertyValue(
      objectId: takasakiId,
      property: property,
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

    final collection = await resolver.resolve(databaseId);

    expect(collection?.objectType.id, placeTypeId);
    expect(collection?.objects.map((object) => object.title), ['札幌']);
    expect(
      collection?.definition.collectionFilter.single.value,
      '北海道',
    );
  });
}
