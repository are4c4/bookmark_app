import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selection context resolves current Relation choices canonically', () async {
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
      name: 'Authors',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final property =
        (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final serreId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
    );
    final tateId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Tate',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: property,
      targetObjectIds: [serreId],
    );

    final context = await service.selectionFor(
      workspaceId: workspaceId,
      sourceObjectId: bookId,
      property: property,
    );

    expect(context.sourceObject.id, bookId);
    expect(context.property.id, property.id);
    expect(context.targetObjectType.id, personTypeId);
    expect(
      context.candidates.map((object) => object.id),
      unorderedEquals([serreId, tateId]),
    );
    expect(context.selectedObjectIds, [serreId]);
    expect(context.selectedObjects.map((object) => object.id), [serreId]);
    expect(context.missingTargetObjectIds, isEmpty);
    expect(context.hasCardinalityViolation, isFalse);
  });

  test('selection context surfaces missing target ids without dropping them', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
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
      name: 'Authors',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final property =
        (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final serreId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
    );
    await genericStore.setValue(
      recordId: bookId,
      propertyId: property.id,
      value: <String, dynamic>{'objectIds': [serreId, 999999]},
    );

    final context = await service.selectionFor(
      workspaceId: workspaceId,
      sourceObjectId: bookId,
      property: property,
    );

    expect(context.selectedObjectIds, [serreId, 999999]);
    expect(context.selectedObjects.map((object) => object.id), [serreId]);
    expect(context.missingTargetObjectIds, [999999]);
  });

  test('selection context reports legacy single Relation cardinality drift', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
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
      multiple: false,
    );
    final property =
        (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final firstId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'First',
    );
    final secondId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Second',
    );
    await genericStore.setValue(
      recordId: bookId,
      propertyId: property.id,
      value: <String, dynamic>{'objectIds': [firstId, secondId]},
    );

    final context = await service.selectionFor(
      workspaceId: workspaceId,
      sourceObjectId: bookId,
      property: property,
    );

    expect(context.selectedObjectIds, [firstId, secondId]);
    expect(context.hasCardinalityViolation, isTrue);
  });

  test('selection context rejects a source Object from another ObjectType', () async {
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
    final property =
        (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final wrongSourceId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Not a book',
    );

    await expectLater(
      service.selectionFor(
        workspaceId: workspaceId,
        sourceObjectId: wrongSourceId,
        property: property,
      ),
      throwsArgumentError,
    );
  });
}
