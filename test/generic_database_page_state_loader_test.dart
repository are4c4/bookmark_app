import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_gallery_cover_source_service.dart';
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
    'loads only Relation target record catalogs for page projection',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final projectionStore = _TrackingGenericDatabaseStore(database);
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

      final databaseId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Scores',
      );
      final valuePropertyId = await objectStore.createProperty(
        objectTypeId: databaseId,
        name: 'Score',
        type: ObjectPropertyType.number,
      );
      final formulaPropertyId = await computedStore.createFormulaProperty(
        objectTypeId: databaseId,
        name: 'Double',
        expression: '{$valuePropertyId} * 2',
      );
      final brokenFormulaId = await objectStore.createProperty(
        objectTypeId: databaseId,
        name: 'Broken',
        type: ObjectPropertyType.formula,
        config: const <String, dynamic>{'expression': 'not-valid('},
      );
      final objectType = (await objectStore.getObjectType(databaseId))!;
      final valueProperty = objectType.properties.singleWhere(
        (property) => property.id == valuePropertyId,
      );
      final objectId = await objectStore.createObject(
        objectTypeId: databaseId,
        title: 'First',
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: valueProperty,
        value: 3,
      );

      final relatedTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Related',
      );
      final relatedObjectId = await objectStore.createObject(
        objectTypeId: relatedTypeId,
        title: 'Second',
      );
      await objectStore.createRelationProperty(
        objectTypeId: databaseId,
        name: 'Related record',
        targetObjectTypeId: relatedTypeId,
      );

      final unrelatedTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Unrelated',
      );
      await objectStore.createObject(
        objectTypeId: unrelatedTypeId,
        title: 'Never loaded for Relation projection',
      );

      int? resolvedCreateModeFor;
      int? resolvedCoverSourcesFor;
      final loader = GenericDatabasePageStateLoader(
        pageLoader: pageLoader,
        genericStore: projectionStore,
        computedStore: computedStore,
        createModeForObjectType: (objectTypeId) async {
          resolvedCreateModeFor = objectTypeId;
          return GenericDatabaseCreateMode.weblinkUrl;
        },
        galleryCoverSourcesForObjectType: (objectTypeId) async {
          resolvedCoverSourcesFor = objectTypeId;
          return const <GalleryCoverSourceOption>[
            GalleryCoverSourceOption(
              source: GalleryCoverSource.none(),
              label: 'なし',
            ),
          ];
        },
      );

      final state = await loader.load(
        databaseId: databaseId,
        workspaceId: workspaceId,
      );

      expect(state.database?.id, databaseId);
      expect(state.objectType?.id, databaseId);
      expect(state.objects.map((object) => object.id), [objectId]);
      expect(state.records.map((record) => record.id), [objectId]);
      expect(state.objectTypes.map((type) => type.id).toSet(), {
        databaseId,
        relatedTypeId,
        unrelatedTypeId,
      });
      expect(state.recordsByType.keys, [relatedTypeId]);
      expect(state.recordsByType[relatedTypeId]?.single.id, relatedObjectId);
      expect(state.recordsByType.containsKey(unrelatedTypeId), isFalse);
      expect(projectionStore.listAllDatabasesCalls, 1);
      expect(projectionStore.listRecordsDatabaseIds, [relatedTypeId]);
      expect(state.computedValues[objectId]?[formulaPropertyId], 6);
      expect(state.computedValues[objectId]?[brokenFormulaId], isNull);
      expect(state.galleryCoverSources.single.label, 'なし');
      expect(
        state.galleryCoverSources.single.source,
        const GalleryCoverSource.none(),
      );
      expect(state.createMode, GenericDatabaseCreateMode.weblinkUrl);
      expect(resolvedCreateModeFor, databaseId);
      expect(resolvedCoverSourcesFor, databaseId);

      final failingCoverLoader = GenericDatabasePageStateLoader(
        pageLoader: pageLoader,
        genericStore: genericStore,
        computedStore: computedStore,
        createModeForObjectType: (_) async => GenericDatabaseCreateMode.generic,
        galleryCoverSourcesForObjectType: (_) async {
          throw StateError('cover discovery unavailable');
        },
      );
      final failingCoverState = await failingCoverLoader.load(
        databaseId: databaseId,
        workspaceId: workspaceId,
      );
      expect(failingCoverState.galleryCoverSources, isEmpty);

      var missingTypeResolverCalls = 0;
      final missingTypeLoader = GenericDatabasePageStateLoader(
        pageLoader: pageLoader,
        genericStore: genericStore,
        computedStore: computedStore,
        createModeForObjectType: (_) async => GenericDatabaseCreateMode.generic,
        galleryCoverSourcesForObjectType: (_) async {
          missingTypeResolverCalls++;
          return const <GalleryCoverSourceOption>[];
        },
      );
      final missingTypeState = await missingTypeLoader.load(
        databaseId: -1,
        workspaceId: workspaceId,
      );
      expect(missingTypeState.objectType, isNull);
      expect(missingTypeState.galleryCoverSources, isEmpty);
      expect(missingTypeResolverCalls, 0);
    },
  );
}

class _TrackingGenericDatabaseStore extends GenericDatabaseStore {
  _TrackingGenericDatabaseStore(super.database);

  int listAllDatabasesCalls = 0;
  final List<int> listRecordsDatabaseIds = <int>[];

  @override
  Future<List<GenericDatabaseDefinitionRecord>> listAllDatabases(
    int workspaceId,
  ) async {
    listAllDatabasesCalls++;
    return super.listAllDatabases(workspaceId);
  }

  @override
  Future<List<GenericRecord>> listRecords(int databaseId) async {
    listRecordsDatabaseIds.add(databaseId);
    return super.listRecords(databaseId);
  }
}
