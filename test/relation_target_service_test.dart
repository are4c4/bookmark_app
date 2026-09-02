import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target candidates use canonical persisted Relation metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final service = RelationTargetService(objectStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final placeTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Place',
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final stored = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final stale = ObjectPropertyDefinition(
      id: stored.id,
      objectTypeId: stored.objectTypeId,
      name: stored.name,
      type: stored.type,
      sortOrder: stored.sortOrder,
      config: <String, dynamic>{
        ...stored.config,
        'targetObjectTypeId': placeTypeId,
      },
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
    );
    await objectStore.createObject(
      objectTypeId: placeTypeId,
      title: 'Paris',
    );

    final result = await service.candidatesFor(
      workspaceId: workspaceId,
      property: stale,
    );

    expect(result.property.id, stored.id);
    expect(result.property.targetObjectTypeId, personTypeId);
    expect(result.targetObjectType.id, personTypeId);
    expect(result.objects.map((object) => object.id), [personId]);
  });

  test('target candidates reject a Property from another source ObjectType', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final service = RelationTargetService(objectStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final stored = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final forged = ObjectPropertyDefinition(
      id: stored.id,
      objectTypeId: personTypeId,
      name: stored.name,
      type: stored.type,
      sortOrder: stored.sortOrder,
      config: stored.config,
    );

    await expectLater(
      service.candidatesFor(workspaceId: workspaceId, property: forged),
      throwsArgumentError,
    );
  });

  test('target candidates reject cross-workspace Relation metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaces = WorkspaceStore(database);
    final workspaceA = await workspaces.initialize();
    final workspaceB = await workspaces.createWorkspace('Other');
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = RelationTargetService(objectStore);

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceA,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceB,
      name: 'Target',
    );
    await genericStore.createProperty(
      databaseId: sourceTypeId,
      name: 'Broken',
      type: 'relation',
      config: <String, dynamic>{
        'targetObjectTypeId': targetTypeId,
        'multiple': true,
      },
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!.properties.single;

    await expectLater(
      service.candidatesFor(workspaceId: workspaceA, property: property),
      throwsStateError,
    );
  });

  test('target candidates reject a missing persisted Relation Property', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final service = RelationTargetService(objectStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final fake = ObjectPropertyDefinition(
      id: 999999,
      objectTypeId: bookTypeId,
      name: 'Fake',
      type: ObjectPropertyType.objectRelation,
      sortOrder: 0,
      config: const <String, dynamic>{
        'targetObjectTypeId': 999999,
        'multiple': true,
      },
    );

    await expectLater(
      service.candidatesFor(workspaceId: workspaceId, property: fake),
      throwsArgumentError,
    );
  });
}
