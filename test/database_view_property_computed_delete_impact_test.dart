import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete impact blocks Formula and cross-ObjectType Rollup target refs',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final computed = ObjectComputedValueStore(objectStore);
    final service = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: DatabaseViewStore(database),
    );

    final orderTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Order',
    );
    final amountPropertyId = await objectStore.createProperty(
      objectTypeId: orderTypeId,
      name: 'Amount',
      type: ObjectPropertyType.number,
    );
    final formulaPropertyId = await computed.createFormulaProperty(
      objectTypeId: orderTypeId,
      name: 'Double Amount',
      expression: '{$amountPropertyId} * 2',
    );

    final dashboardTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Dashboard',
    );
    final ordersRelationId = await objectStore.createRelationProperty(
      objectTypeId: dashboardTypeId,
      name: 'Orders',
      targetObjectTypeId: orderTypeId,
      multiple: true,
    );
    final rollupPropertyId = await computed.createRollupProperty(
      objectTypeId: dashboardTypeId,
      name: 'Total Amount',
      relationPropertyId: ordersRelationId,
      targetPropertyId: amountPropertyId,
      aggregation: 'sum',
    );

    final impact = await service.inspectDelete(
      objectTypeId: orderTypeId,
      propertyId: amountPropertyId,
    );

    expect(impact.hasComputedPropertyImpact, isTrue);
    expect(impact.computedReferences, hasLength(2));
    expect(
      impact.computedReferences
          .map((reference) => (
                reference.propertyId,
                reference.kind,
              ))
          .toSet(),
      {
        (
          formulaPropertyId,
          ObjectPropertyComputedReferenceKind.formula,
        ),
        (
          rollupPropertyId,
          ObjectPropertyComputedReferenceKind.rollupTarget,
        ),
      },
    );
    expect(
      impact.computedReferences
          .singleWhere((reference) => reference.propertyId == rollupPropertyId)
          .objectTypeName,
      'Dashboard',
    );
  });

  test('delete impact blocks Rollup relation Property references', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final computed = ObjectComputedValueStore(objectStore);
    final service = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: DatabaseViewStore(database),
    );

    final itemTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Item',
    );
    final collectionTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Collection',
    );
    final relationPropertyId = await objectStore.createRelationProperty(
      objectTypeId: collectionTypeId,
      name: 'Items',
      targetObjectTypeId: itemTypeId,
      multiple: true,
    );
    final rollupPropertyId = await computed.createRollupProperty(
      objectTypeId: collectionTypeId,
      name: 'Item count',
      relationPropertyId: relationPropertyId,
      aggregation: 'count',
    );

    final impact = await service.inspectDelete(
      objectTypeId: collectionTypeId,
      propertyId: relationPropertyId,
    );

    expect(impact.computedReferences, hasLength(1));
    expect(impact.computedReferences.single.propertyId, rollupPropertyId);
    expect(
      impact.computedReferences.single.kind,
      ObjectPropertyComputedReferenceKind.rollupRelation,
    );
  });
}
