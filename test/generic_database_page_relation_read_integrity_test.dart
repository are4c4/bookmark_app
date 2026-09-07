import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_page_state_loader.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Database page Relation projection fails closed without repairing corruption',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final computedStore = ObjectComputedValueStore(objectStore);
      final collectionStore = DatabaseCollectionStore(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final pageLoader = GenericDatabaseCollectionPageLoader(
        genericStore: genericStore,
        collectionResolver: DatabaseCollectionResolver(
          collectionStore: collectionStore,
          objectStore: objectStore,
        ),
      );
      final loader = GenericDatabasePageStateLoader(
        pageLoader: pageLoader,
        genericStore: genericStore,
        computedStore: computedStore,
        createModeForObjectType: (_) async => GenericDatabaseCreateMode.generic,
      );

      final sourceTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Book',
      );
      final targetTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Author',
      );
      final relationPropertyId = await objectStore.createRelationProperty(
        objectTypeId: sourceTypeId,
        name: 'Authors',
        targetObjectTypeId: targetTypeId,
        multiple: true,
      );
      final relationProperty = (await objectStore.getObjectType(sourceTypeId))!
          .properties
          .singleWhere((property) => property.id == relationPropertyId);
      final sourceId = await objectStore.createObject(
        objectTypeId: sourceTypeId,
        title: 'Number Theory',
      );
      final targetId = await objectStore.createObject(
        objectTypeId: targetTypeId,
        title: 'Serre',
      );
      await objectStore.setRelation(
        objectId: sourceId,
        property: relationProperty,
        targetObjectIds: [targetId],
      );

      final healthyState = await loader.load(
        databaseId: sourceTypeId,
        workspaceId: workspaceId,
      );
      expect(
        ObjectRelationValue.fromJson(
          healthyState.records.single.values[relationPropertyId],
        ).objectIds,
        [targetId],
      );

      await genericStore.setValue(
        recordId: sourceId,
        propertyId: relationPropertyId,
        value: <String, dynamic>{
          'objectIds': <dynamic>[targetId, 'broken'],
        },
      );
      final edgesBefore = await objectStore.outgoingRelations(sourceId);

      final corruptState = await loader.load(
        databaseId: sourceTypeId,
        workspaceId: workspaceId,
      );

      expect(
        ObjectRelationValue.fromJson(
          corruptState.records.single.values[relationPropertyId],
        ).objectIds,
        isEmpty,
      );
      final persisted = (await genericStore.listRecords(sourceTypeId)).single;
      expect(
        persisted.values[relationPropertyId],
        <String, dynamic>{
          'objectIds': <dynamic>[targetId, 'broken'],
        },
      );
      final edgesAfter = await objectStore.outgoingRelations(sourceId);
      expect(edgesAfter.length, edgesBefore.length);
      expect(edgesAfter.single.sourceObjectId, edgesBefore.single.sourceObjectId);
      expect(edgesAfter.single.propertyId, edgesBefore.single.propertyId);
      expect(edgesAfter.single.targetObjectId, edgesBefore.single.targetObjectId);
      expect(edgesAfter.single.position, edgesBefore.single.position);
    },
  );
}
