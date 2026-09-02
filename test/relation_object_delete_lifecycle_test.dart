import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

RelationMutationService _service(
  GenericDatabaseStore genericStore,
  ObjectStore objectStore,
) {
  return RelationMutationService(
    objectStore: objectStore,
    bidirectionalStore: BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    ),
    genericStore: genericStore,
  );
}

void main() {
  test('deleting a target Object detaches unidirectional Relation values', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = _service(genericStore, objectStore);

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
      name: 'Authors',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final relation =
        (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final authorA = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'A',
    );
    final authorB = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'B',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: relation,
      targetObjectIds: [authorA, authorB],
    );

    await service.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: personTypeId,
      objectId: authorA,
    );

    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[relation.id]).objectIds,
      [authorB],
    );
    expect(
      (await objectStore.listObjects(personTypeId)).map((item) => item.id),
      [authorB],
    );
    expect(await objectStore.backlinks(authorA), isEmpty);
  });

  test('deleting a bidirectional target clears the inverse source value', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
      sourceMultiple: false,
      inverseMultiple: true,
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );
    await service.setRelation(
      objectId: bookId,
      property: pair.sourceProperty,
      targetObjectIds: [personId],
    );

    await service.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: personTypeId,
      objectId: personId,
    );

    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[pair.sourceProperty.id]).objectIds,
      isEmpty,
    );
    expect(await objectStore.listObjects(personTypeId), isEmpty);
  });

  test('deleting an Object cleans legacy Relation values after index rebuild', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = _service(genericStore, objectStore);

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
      multiple: false,
    );
    final relation =
        (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );

    // Simulate persisted legacy data written before the normalized edge index.
    await genericStore.setValue(
      recordId: bookId,
      propertyId: relation.id,
      value: personId,
    );
    expect(await objectStore.backlinks(personId), isEmpty);

    await service.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: personTypeId,
      objectId: personId,
    );

    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[relation.id]).objectIds,
      isEmpty,
    );
    expect(await objectStore.listObjects(personTypeId), isEmpty);
  });

  test('delete Object rejects a mismatched workspace before mutation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceA = await workspaceStore.initialize();
    final workspaceB = await workspaceStore.createWorkspace('Other');
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = _service(genericStore, objectStore);

    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceA,
      name: 'Person',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );

    await expectLater(
      service.deleteObject(
        workspaceId: workspaceB,
        objectTypeId: personTypeId,
        objectId: personId,
      ),
      throwsArgumentError,
    );
    expect((await objectStore.listObjects(personTypeId)).single.id, personId);
  });
}
