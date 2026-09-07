import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolved Relation reads expose canonical Property and Object neighbors', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final readService = RelationReadService(objectStore);

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

    final authorProperty =
        (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: [personId],
    );

    final outgoing = await readService.outgoing(
      sourceObjectTypeId: bookTypeId,
      sourceObjectId: bookId,
    );
    final backlinks = await readService.backlinks(
      workspaceId: workspaceId,
      targetObjectId: personId,
    );

    expect(outgoing, hasLength(1));
    expect(outgoing.single.property.id, authorProperty.id);
    expect(outgoing.single.property.name, 'Author');
    expect(outgoing.single.targetObject.id, personId);
    expect(outgoing.single.targetObject.title, 'Serre');

    expect(backlinks, hasLength(1));
    expect(backlinks.single.property.id, authorProperty.id);
    expect(backlinks.single.sourceObject.id, bookId);
    expect(backlinks.single.sourceObject.title, 'Number Theory');
  });

  test('resolved outgoing reads ignore edges outside the declared source ObjectType', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final readService = RelationReadService(objectStore);

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
    await objectStore.setRelation(
      objectId: bookId,
      property: relation,
      targetObjectIds: [personId],
    );

    final wrongType = await readService.outgoing(
      sourceObjectTypeId: personTypeId,
      sourceObjectId: bookId,
    );
    expect(wrongType, isEmpty);
  });

  test('canonical reads fail closed on malformed persisted Relation values', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final readService = RelationReadService(objectStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Authors',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final relation = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((property) => property.id == relationId);
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Author',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: relation,
      targetObjectIds: [personId],
    );
    await genericStore.setValue(
      recordId: bookId,
      propertyId: relationId,
      value: <dynamic>[personId, 'broken'],
    );

    expect(
      await readService.outgoing(
        sourceObjectTypeId: bookTypeId,
        sourceObjectId: bookId,
      ),
      isEmpty,
    );
    expect(
      await readService.backlinks(
        workspaceId: workspaceId,
        targetObjectId: personId,
      ),
      isEmpty,
    );
    final edges = (await objectStore.outgoingRelations(bookId))
        .where((edge) => edge.propertyId == relationId)
        .toList(growable: false);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, personId);
  });

  test('canonical reads fail closed on serialized Relation/index disagreement', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final readService = RelationReadService(objectStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final relation = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((property) => property.id == relationId);
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Author',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: relation,
      targetObjectIds: [personId],
    );
    await genericStore.setValue(
      recordId: bookId,
      propertyId: relationId,
      value: null,
    );

    expect(
      await readService.outgoing(
        sourceObjectTypeId: bookTypeId,
        sourceObjectId: bookId,
      ),
      isEmpty,
    );
    expect(
      await readService.backlinks(
        workspaceId: workspaceId,
        targetObjectId: personId,
      ),
      isEmpty,
    );
    final edges = (await objectStore.outgoingRelations(bookId))
        .where((edge) => edge.propertyId == relationId)
        .toList(growable: false);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, personId);
  });
}
