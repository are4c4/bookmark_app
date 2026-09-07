import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'secondary collection View and collection filter block Property deletion workspace-wide',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final viewStore = DatabaseViewStore(database);
      final collectionStore = DatabaseCollectionStore(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final service = DatabaseViewPropertySchemaService(
        objectStore: objectStore,
        genericStore: genericStore,
        viewStore: viewStore,
      );

      final plantTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Plant',
      );
      final scorePropertyId = await objectStore.createProperty(
        objectTypeId: plantTypeId,
        name: 'Score',
        type: ObjectPropertyType.number,
      );
      final dashboardDatabaseId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Plant Dashboard',
      );

      await collectionStore.write(
        DatabaseCollectionDefinition(
          databaseId: dashboardDatabaseId,
          workspaceId: workspaceId,
          targetObjectTypeId: plantTypeId,
          collectionFilter: [
            ObjectFilterRule(
              propertyId: scorePropertyId,
              operator: ObjectFilterOperator.greaterThanOrEqual,
              value: 3,
            ),
          ],
        ),
      );

      final definition = DatabaseDefinition(
        key: 'custom:$dashboardDatabaseId',
        label: 'Plant Dashboard',
        icon: Icons.dashboard_outlined,
        properties: [
          DatabasePropertyDefinition(
            key: 'p:$scorePropertyId',
            label: 'Score',
            type: DatabasePropertyType.number,
            icon: Icons.numbers,
          ),
        ],
        defaultLayout: 'table',
      );
      final viewId = await viewStore.createView(
        workspaceId: workspaceId,
        definition: definition,
        name: 'High scores',
        filters: {
          'propertyRules': [
            ObjectFilterRule(
              propertyId: scorePropertyId,
              operator: ObjectFilterOperator.greaterThan,
              value: 5,
            ).toJson(),
          ],
        },
        visibleProperties: ['p:$scorePropertyId'],
        propertyOrder: ['p:$scorePropertyId'],
      );

      var impact = await service.inspectDelete(
        objectTypeId: plantTypeId,
        propertyId: scorePropertyId,
      );

      expect(impact.collectionReferences, hasLength(1));
      expect(impact.collectionReferences.single.databaseId, dashboardDatabaseId);
      expect(impact.collectionReferences.single.databaseName, 'Plant Dashboard');
      expect(impact.viewReferences, hasLength(1));
      expect(impact.viewReferences.single.viewId, viewId);
      expect(
        impact.viewReferences.single.kinds,
        containsAll(<DatabaseViewPropertyReferenceKind>[
          DatabaseViewPropertyReferenceKind.visible,
          DatabaseViewPropertyReferenceKind.order,
          DatabaseViewPropertyReferenceKind.filter,
        ]),
      );

      expect(
        await service.detachViewReferences(
          objectTypeId: plantTypeId,
          propertyId: scorePropertyId,
        ),
        1,
      );

      impact = await service.inspectDelete(
        objectTypeId: plantTypeId,
        propertyId: scorePropertyId,
      );
      expect(impact.viewReferences, isEmpty);
      expect(impact.collectionReferences, hasLength(1));

      final persistedCollection =
          await collectionStore.readEffective(dashboardDatabaseId);
      expect(persistedCollection, isNotNull);
      expect(
        persistedCollection!.collectionFilter.single.propertyId,
        scorePropertyId,
      );
      final persistedView = (await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: definition.key,
      ))
          .single;
      expect(persistedView.visibleProperties, isEmpty);
      expect(persistedView.propertyOrder, isEmpty);
      expect(persistedView.filters['propertyRules'], isEmpty);
    },
  );
}
