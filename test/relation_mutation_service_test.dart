import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

RelationMutationService serviceFor(
  GenericDatabaseStore genericStore,
  ObjectStore objectStore,
  BidirectionalRelationStore bidirectionalStore,
) =>
    RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );

void main() {
  test('safe mutation facade synchronizes a bidirectional Relation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = serviceFor(genericStore, objectStore, bidirectionalStore);

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final bookId = await objectStore.createObject(objectTypeId: bookTypeId, title: 'Book');
    final personId = await objectStore.createObject(objectTypeId: personTypeId, title: 'Person');

    await service.setRelation(
      objectId: bookId,
      property: pair.sourceProperty,
      targetObjectIds: [personId],
    );

    final person = (await objectStore.listObjects(personTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(person.values[pair.inverseProperty.id]).objectIds,
      [bookId],
    );
  });

  test('safe deletion removes both sides of a bidirectional pair', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = serviceFor(genericStore, objectStore, bidirectionalStore);

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );

    await service.deleteRelationProperty(pair.sourceProperty);

    expect((await objectStore.getObjectType(bookTypeId))!.properties, isEmpty);
    expect((await objectStore.getObjectType(personTypeId))!.properties, isEmpty);
  });

  test('inconsistent pair metadata fails closed instead of deleting one side', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = serviceFor(genericStore, objectStore, bidirectionalStore);

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );

    final inverse = (await genericStore.listProperties(personTypeId))
        .singleWhere((property) => property.id == pair.inverseProperty.id);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: inverse.id,
        databaseId: inverse.databaseId,
        name: inverse.name,
        type: inverse.type,
        sortOrder: inverse.sortOrder,
        config: <String, dynamic>{...inverse.config, 'bidirectional': false},
      ),
    );

    await expectLater(service.deleteRelationProperty(pair.sourceProperty), throwsStateError);
    expect((await objectStore.getObjectType(bookTypeId))!.properties, hasLength(1));
    expect((await objectStore.getObjectType(personTypeId))!.properties, hasLength(1));
  });

  test('stale caller config cannot redirect a unidirectional Relation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = serviceFor(genericStore, objectStore, bidirectionalStore);

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    final placeTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Place');
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
      config: <String, dynamic>{...stored.config, 'targetObjectTypeId': placeTypeId},
    );
    final bookId = await objectStore.createObject(objectTypeId: bookTypeId, title: 'Book');
    final placeId = await objectStore.createObject(objectTypeId: placeTypeId, title: 'Place');

    await expectLater(
      service.setRelation(objectId: bookId, property: stale, targetObjectIds: [placeId]),
      throwsArgumentError,
    );
    expect(await objectStore.outgoingRelations(bookId), isEmpty);
  });

  test('safe rename updates both names for a bidirectional pair', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = serviceFor(genericStore, objectStore, bidirectionalStore);

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );

    final renamed = await service.renameRelationProperty(
      property: pair.sourceProperty,
      name: 'Writer',
      inverseName: 'Written books',
    );

    expect(renamed.name, 'Writer');
    expect((await objectStore.getObjectType(bookTypeId))!.properties.single.name, 'Writer');
    expect((await objectStore.getObjectType(personTypeId))!.properties.single.name, 'Written books');
  });

  test('safe rename preserves unidirectional Relation configuration', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = serviceFor(genericStore, objectStore, bidirectionalStore);

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final relation = (await objectStore.getObjectType(bookTypeId))!.properties.single;

    final renamed = await service.renameRelationProperty(property: relation, name: 'Writer');

    expect(renamed.name, 'Writer');
    expect(renamed.targetObjectTypeId, personTypeId);
    expect(renamed.allowsMultipleRelations, isFalse);
  });
}
