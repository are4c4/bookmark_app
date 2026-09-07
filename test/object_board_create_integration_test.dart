import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Relation-group creation writes through the canonical Relation path',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = ObjectBoardCreateService(
      objectStore,
      relationMutations: RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      ),
    );

    final taskTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Task',
    );
    final statusTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Status',
    );
    final statusPropertyId = await objectStore.createRelationProperty(
      objectTypeId: taskTypeId,
      name: 'Status',
      targetObjectTypeId: statusTypeId,
      multiple: false,
    );
    final taskType = (await objectStore.getObjectType(taskTypeId))!;
    final statusProperty = taskType.properties.singleWhere(
      (property) => property.id == statusPropertyId,
    );
    final statusId = await objectStore.createObject(
      objectTypeId: statusTypeId,
      title: 'Doing',
    );
    final targetGroup = ObjectGroupBucket<AppObject>(
      key: '$statusId',
      label: 'Doing',
      value: statusId,
      items: const <AppObject>[],
      isEmptyGroup: false,
    );

    final taskId = await service.create(
      objectTypeId: taskTypeId,
      title: 'Write tests',
      groupProperty: statusProperty,
      targetGroup: targetGroup,
    );

    final task = (await objectStore.listObjects(taskTypeId)).single;
    expect(task.id, taskId);
    expect(
      ObjectRelationValue.fromJson(task.values[statusPropertyId]).objectIds,
      [statusId],
    );
    final edges = await objectStore.outgoingRelations(taskId);
    expect(edges, hasLength(1));
    expect(edges.single.propertyId, statusPropertyId);
    expect(edges.single.targetObjectId, statusId);
  });

  test('transaction rollback leaves no orphan when Relation preset fails',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    // If create() still relied on an explicit cleanup delete, this store would
    // make that cleanup fail and the newly-created Task would remain orphaned.
    final objectStore = _DeleteFailingObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = ObjectBoardCreateService(
      objectStore,
      relationMutations: RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      ),
    );

    final taskTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Task',
    );
    final statusTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Status',
    );
    final unrelatedTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Unrelated',
    );
    final statusPropertyId = await objectStore.createRelationProperty(
      objectTypeId: taskTypeId,
      name: 'Status',
      targetObjectTypeId: statusTypeId,
      multiple: false,
    );
    final taskType = (await objectStore.getObjectType(taskTypeId))!;
    final statusProperty = taskType.properties.singleWhere(
      (property) => property.id == statusPropertyId,
    );
    final unrelatedId = await objectStore.createObject(
      objectTypeId: unrelatedTypeId,
      title: 'Wrong target',
    );
    final targetGroup = ObjectGroupBucket<AppObject>(
      key: '$unrelatedId',
      label: 'Wrong target',
      value: unrelatedId,
      items: const <AppObject>[],
      isEmptyGroup: false,
    );

    await expectLater(
      service.create(
        objectTypeId: taskTypeId,
        title: 'Must fail',
        groupProperty: statusProperty,
        targetGroup: targetGroup,
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(await objectStore.listObjects(taskTypeId), isEmpty);
  });
}

class _DeleteFailingObjectStore extends ObjectStore {
  _DeleteFailingObjectStore(GenericDatabaseStore genericStore)
      : super(genericStore);

  @override
  Future<void> deleteObject(int id) async {
    throw StateError('cleanup failed');
  }
}
