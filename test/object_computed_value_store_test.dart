import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formula evaluates numeric property references with precedence', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final computed = ObjectComputedValueStore(objectStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '商品',
    );
    final priceId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: '価格',
      type: ObjectPropertyType.number,
    );
    final countId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: '数量',
      type: ObjectPropertyType.number,
    );
    final totalId = await computed.createFormulaProperty(
      objectTypeId: typeId,
      name: '合計',
      expression: '{$priceId} * {$countId} + 100',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: '商品A',
    );
    final type = (await objectStore.getObjectType(typeId))!;
    final price = type.properties.firstWhere((item) => item.id == priceId);
    final count = type.properties.firstWhere((item) => item.id == countId);
    final total = type.properties.firstWhere((item) => item.id == totalId);

    await objectStore.setPropertyValue(
      objectId: objectId,
      property: price,
      value: 1200,
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: count,
      value: 2,
    );
    final object = (await objectStore.listObjects(typeId)).single;

    expect(await computed.evaluate(object: object, property: total), 2500);
  });

  test('rollup aggregates numeric values through a relation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final computed = ObjectComputedValueStore(objectStore);

    final projectType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'プロジェクト',
    );
    final taskType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'タスク',
    );
    final effortId = await objectStore.createProperty(
      objectTypeId: taskType,
      name: '工数',
      type: ObjectPropertyType.number,
    );
    final tasksId = await objectStore.createRelationProperty(
      objectTypeId: projectType,
      name: 'タスク',
      targetObjectTypeId: taskType,
      multiple: true,
    );
    final sumId = await computed.createRollupProperty(
      objectTypeId: projectType,
      name: '合計工数',
      relationPropertyId: tasksId,
      targetPropertyId: effortId,
      aggregation: 'sum',
    );
    final countId = await computed.createRollupProperty(
      objectTypeId: projectType,
      name: 'タスク数',
      relationPropertyId: tasksId,
      aggregation: 'count',
    );

    final taskTypeDef = (await objectStore.getObjectType(taskType))!;
    final effort = taskTypeDef.properties.firstWhere((item) => item.id == effortId);
    final taskA = await objectStore.createObject(objectTypeId: taskType, title: 'A');
    final taskB = await objectStore.createObject(objectTypeId: taskType, title: 'B');
    await objectStore.setPropertyValue(
      objectId: taskA,
      property: effort,
      value: 3,
    );
    await objectStore.setPropertyValue(
      objectId: taskB,
      property: effort,
      value: 5,
    );

    final projectId = await objectStore.createObject(
      objectTypeId: projectType,
      title: 'P',
    );
    final projectTypeDef = (await objectStore.getObjectType(projectType))!;
    final tasks = projectTypeDef.properties.firstWhere((item) => item.id == tasksId);
    final sum = projectTypeDef.properties.firstWhere((item) => item.id == sumId);
    final count = projectTypeDef.properties.firstWhere((item) => item.id == countId);
    await objectStore.setRelation(
      objectId: projectId,
      property: tasks,
      targetObjectIds: [taskA, taskB],
    );
    final project = (await objectStore.listObjects(projectType)).single;

    expect(await computed.evaluate(object: project, property: sum), 8);
    expect(await computed.evaluate(object: project, property: count), 2);
  });

  test('formula returns null when a referenced numeric value is missing', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final computed = ObjectComputedValueStore(objectStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '計算',
    );
    final valueId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: '値',
      type: ObjectPropertyType.number,
    );
    final formulaId = await computed.createFormulaProperty(
      objectTypeId: typeId,
      name: '倍',
      expression: '{$valueId} * 2',
    );
    await objectStore.createObject(objectTypeId: typeId, title: '空');
    final type = (await objectStore.getObjectType(typeId))!;
    final formula = type.properties.firstWhere((item) => item.id == formulaId);
    final object = (await objectStore.listObjects(typeId)).single;

    expect(await computed.evaluate(object: object, property: formula), isNull);
  });

  test('formula returns null on division by zero', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final computed = ObjectComputedValueStore(objectStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '計算',
    );
    final formulaId = await computed.createFormulaProperty(
      objectTypeId: typeId,
      name: 'ゼロ除算',
      expression: '10 / 0',
    );
    await objectStore.createObject(objectTypeId: typeId, title: '式');
    final type = (await objectStore.getObjectType(typeId))!;
    final formula = type.properties.firstWhere((item) => item.id == formulaId);
    final object = (await objectStore.listObjects(typeId)).single;

    expect(await computed.evaluate(object: object, property: formula), isNull);
  });
}
