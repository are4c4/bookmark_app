import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_management_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicateSchema remaps Formula and self-Rollup Property references',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final computedStore = ObjectComputedValueStore(objectStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Computed source',
    );
    final amountId = await objectStore.createProperty(
      objectTypeId: sourceId,
      name: 'Amount',
      type: ObjectPropertyType.number,
    );
    await computedStore.createFormulaProperty(
      objectTypeId: sourceId,
      name: 'Double',
      expression: '{$amountId} * 2',
    );
    final childrenId = await objectStore.createRelationProperty(
      objectTypeId: sourceId,
      name: 'Children',
      targetObjectTypeId: sourceId,
    );
    await computedStore.createRollupProperty(
      objectTypeId: sourceId,
      name: 'Child total',
      relationPropertyId: childrenId,
      targetPropertyId: amountId,
      aggregation: 'sum',
    );

    final copyId = await management.duplicateSchema(objectTypeId: sourceId);
    final copy = (await objectStore.getObjectType(copyId))!;
    final copyAmount = copy.properties.singleWhere((item) => item.name == 'Amount');
    final copyFormula = copy.properties.singleWhere((item) => item.name == 'Double');
    final copyChildren = copy.properties.singleWhere((item) => item.name == 'Children');
    final copyRollup = copy.properties.singleWhere((item) => item.name == 'Child total');

    expect(copyFormula.config['expression'], '{${copyAmount.id}} * 2');
    expect(copyFormula.config['expression'], isNot(contains('{$amountId}')));
    expect(copyChildren.targetObjectTypeId, copyId);
    expect(copyRollup.config['relationPropertyId'], copyChildren.id);
    expect(copyRollup.config['targetPropertyId'], copyAmount.id);

    final parentId = await objectStore.createObject(
      objectTypeId: copyId,
      title: 'Parent',
    );
    final childId = await objectStore.createObject(
      objectTypeId: copyId,
      title: 'Child',
    );
    await objectStore.setPropertyValue(
      objectId: parentId,
      property: copyAmount,
      value: 5,
    );
    await objectStore.setPropertyValue(
      objectId: childId,
      property: copyAmount,
      value: 7,
    );
    await objectStore.setRelation(
      objectId: parentId,
      property: copyChildren,
      targetObjectIds: <int>[childId],
    );

    final parent = (await objectStore.listObjects(copyId))
        .singleWhere((item) => item.id == parentId);
    expect(
      await computedStore.evaluate(object: parent, property: copyFormula),
      10,
    );
    expect(
      await computedStore.evaluate(object: parent, property: copyRollup),
      7,
    );
  });

  test('duplicateSchema keeps external Rollup target Property identity', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final computedStore = ObjectComputedValueStore(objectStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final targetId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'External target',
    );
    final targetValueId = await objectStore.createProperty(
      objectTypeId: targetId,
      name: 'Value',
      type: ObjectPropertyType.number,
    );
    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'External source',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceId,
      name: 'Targets',
      targetObjectTypeId: targetId,
    );
    await computedStore.createRollupProperty(
      objectTypeId: sourceId,
      name: 'Target total',
      relationPropertyId: relationId,
      targetPropertyId: targetValueId,
      aggregation: 'sum',
    );

    final copyId = await management.duplicateSchema(objectTypeId: sourceId);
    final copy = (await objectStore.getObjectType(copyId))!;
    final copyRelation = copy.properties.singleWhere((item) => item.name == 'Targets');
    final copyRollup = copy.properties.singleWhere((item) => item.name == 'Target total');

    expect(copyRelation.targetObjectTypeId, targetId);
    expect(copyRollup.config['relationPropertyId'], copyRelation.id);
    expect(copyRollup.config['targetPropertyId'], targetValueId);
  });
}
