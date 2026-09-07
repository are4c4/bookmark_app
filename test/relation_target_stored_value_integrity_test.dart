import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Relation picker fails closed on malformed persisted value', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = RelationTargetService(objectStore);

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Authors',
      targetObjectTypeId: targetTypeId,
      multiple: true,
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((candidate) => candidate.id == propertyId);
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book',
    );

    await genericStore.setValue(
      recordId: sourceId,
      propertyId: propertyId,
      value: <dynamic>['broken-target-id'],
    );

    await expectLater(
      service.selectionFor(
        workspaceId: workspaceId,
        sourceObjectId: sourceId,
        property: property,
      ),
      throwsStateError,
    );

    final refreshed = (await objectStore.listObjects(sourceTypeId)).single;
    expect(
      refreshed.values[propertyId],
      <dynamic>['broken-target-id'],
    );
    expect(await objectStore.outgoingRelations(sourceId), isEmpty);
  });

  test('Relation picker preserves duplicate persisted ids for diagnostics',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = RelationTargetService(objectStore);

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Authors',
      targetObjectTypeId: targetTypeId,
      multiple: true,
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((candidate) => candidate.id == propertyId);
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book',
    );
    final targetId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Author',
    );

    await objectStore.setRelation(
      objectId: sourceId,
      property: property,
      targetObjectIds: <int>[targetId],
    );
    await genericStore.setValue(
      recordId: sourceId,
      propertyId: propertyId,
      value: <int>[targetId, targetId],
    );

    final context = await service.selectionFor(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      property: property,
    );

    expect(context.selectedObjectIds, <int>[targetId, targetId]);
    expect(
      context.selectedObjects.map((object) => object.id),
      <int>[targetId, targetId],
    );
    expect(context.missingTargetObjectIds, isEmpty);
    expect(context.hasCardinalityViolation, isFalse);

    final edges = await objectStore.outgoingRelations(sourceId);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, targetId);
  });
}
