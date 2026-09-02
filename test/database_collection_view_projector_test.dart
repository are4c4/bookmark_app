import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/database_collection_view_projector.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Database membership is filtered before independent View filtering',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final projector = DatabaseCollectionViewProjector(
      collectionResolver: DatabaseCollectionResolver(
        collectionStore: collectionStore,
        objectStore: objectStore,
      ),
    );

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
    final wantToGoId = await objectStore.createProperty(
      objectTypeId: placeTypeId,
      name: '行きたい',
      type: ObjectPropertyType.checkbox,
    );
    final placeType = (await objectStore.getObjectType(placeTypeId))!;
    final prefecture = placeType.properties.singleWhere(
      (property) => property.id == prefectureId,
    );
    final wantToGo = placeType.properties.singleWhere(
      (property) => property.id == wantToGoId,
    );

    Future<void> createPlace(
      String title,
      String prefectureValue,
      bool wanted,
    ) async {
      final id = await objectStore.createObject(
        objectTypeId: placeTypeId,
        title: title,
      );
      await objectStore.setPropertyValue(
        objectId: id,
        property: prefecture,
        value: prefectureValue,
      );
      await objectStore.setPropertyValue(
        objectId: id,
        property: wantToGo,
        value: wanted,
      );
    }

    await createPlace('札幌', '北海道', true);
    await createPlace('小樽', '北海道', false);
    await createPlace('高崎', '群馬県', true);

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

    final view = DatabaseViewConfig(
      id: 1,
      workspaceId: workspaceId,
      databaseKey: 'custom:$databaseId',
      name: '行きたい場所',
      layoutType: 'gallery',
      filters: <String, dynamic>{
        'query': '',
        'propertyRules': <Map<String, dynamic>>[
          ObjectFilterRule(
            propertyId: wantToGoId,
            operator: ObjectFilterOperator.equals,
            value: true,
          ).toJson(),
        ],
      },
      sorts: const <dynamic>[],
      visibleProperties: const <String>[],
      propertyOrder: const <String>[],
      settings: const <String, dynamic>{},
      sortOrder: 0,
    );

    final result = await projector.project(databaseId: databaseId, view: view);

    expect(
      result?.collection.objects.map((object) => object.title),
      ['札幌', '小樽'],
    );
    expect(result?.view.objects.map((object) => object.title), ['札幌']);
  });

  test('a View from another Database cannot be applied to the collection',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final projector = DatabaseCollectionViewProjector(
      collectionResolver: DatabaseCollectionResolver(
        collectionStore: collectionStore,
        objectStore: objectStore,
      ),
    );
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Collection',
    );
    final otherId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Other',
    );
    final wrongView = DatabaseViewConfig(
      id: 9,
      workspaceId: workspaceId,
      databaseKey: 'custom:$otherId',
      name: 'Wrong',
      layoutType: 'table',
      filters: const <String, dynamic>{},
      sorts: const <dynamic>[],
      visibleProperties: const <String>[],
      propertyOrder: const <String>[],
      settings: const <String, dynamic>{},
      sortOrder: 0,
    );

    await expectLater(
      projector.project(databaseId: databaseId, view: wrongView),
      throwsArgumentError,
    );
  });
}
