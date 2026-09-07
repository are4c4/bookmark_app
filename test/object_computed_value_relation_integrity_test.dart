import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rollup fails closed on corrupt Relation reads without repairing data',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final computed = ObjectComputedValueStore(objectStore);

    final projectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Project',
    );
    final taskTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Task',
    );
    final effortId = await objectStore.createProperty(
      objectTypeId: taskTypeId,
      name: 'Effort',
      type: ObjectPropertyType.number,
    );
    final tasksId = await objectStore.createRelationProperty(
      objectTypeId: projectTypeId,
      name: 'Tasks',
      targetObjectTypeId: taskTypeId,
      multiple: true,
    );
    final countId = await computed.createRollupProperty(
      objectTypeId: projectTypeId,
      name: 'Task count',
      relationPropertyId: tasksId,
      aggregation: 'count',
    );
    final sumId = await computed.createRollupProperty(
      objectTypeId: projectTypeId,
      name: 'Effort sum',
      relationPropertyId: tasksId,
      targetPropertyId: effortId,
      aggregation: 'sum',
    );

    final taskType = (await objectStore.getObjectType(taskTypeId))!;
    final effort = taskType.properties.singleWhere(
      (property) => property.id == effortId,
    );
    final taskId = await objectStore.createObject(
      objectTypeId: taskTypeId,
      title: 'Task',
    );
    await objectStore.setPropertyValue(
      objectId: taskId,
      property: effort,
      value: 5,
    );

    final projectId = await objectStore.createObject(
      objectTypeId: projectTypeId,
      title: 'Project',
    );
    final emptyProjectId = await objectStore.createObject(
      objectTypeId: projectTypeId,
      title: 'Empty project',
    );
    final projectType = (await objectStore.getObjectType(projectTypeId))!;
    final tasks = projectType.properties.singleWhere(
      (property) => property.id == tasksId,
    );
    final count = projectType.properties.singleWhere(
      (property) => property.id == countId,
    );
    final sum = projectType.properties.singleWhere(
      (property) => property.id == sumId,
    );
    await objectStore.setRelation(
      objectId: projectId,
      property: tasks,
      targetObjectIds: [taskId],
    );

    AppObject project = (await objectStore.listObjects(projectTypeId))
        .singleWhere((object) => object.id == projectId);
    final emptyProject = (await objectStore.listObjects(projectTypeId))
        .singleWhere((object) => object.id == emptyProjectId);
    expect(await computed.evaluate(object: project, property: count), 1);
    expect(await computed.evaluate(object: project, property: sum), 5);
    expect(await computed.evaluate(object: emptyProject, property: count), 0);

    await genericStore.setValue(
      recordId: projectId,
      propertyId: tasksId,
      value: <dynamic>[taskId, 'broken'],
    );
    project = (await objectStore.listObjects(projectTypeId))
        .singleWhere((object) => object.id == projectId);

    expect(await computed.evaluate(object: project, property: count), isNull);
    expect(await computed.evaluate(object: project, property: sum), isNull);
    expect(project.values[tasksId], <dynamic>[taskId, 'broken']);
    var edges = (await objectStore.outgoingRelations(projectId))
        .where((edge) => edge.propertyId == tasksId)
        .toList(growable: false);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, taskId);

    await genericStore.setValue(
      recordId: projectId,
      propertyId: tasksId,
      value: <int>[taskId],
    );
    await database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      [projectId, tasksId],
    );
    project = (await objectStore.listObjects(projectTypeId))
        .singleWhere((object) => object.id == projectId);

    expect(await computed.evaluate(object: project, property: count), isNull);
    expect(await computed.evaluate(object: project, property: sum), isNull);
    expect(project.values[tasksId], <int>[taskId]);
    edges = (await objectStore.outgoingRelations(projectId))
        .where((edge) => edge.propertyId == tasksId)
        .toList(growable: false);
    expect(edges, isEmpty);
  });
}
