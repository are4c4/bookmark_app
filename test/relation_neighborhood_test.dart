import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('neighborhood returns both outgoing and incoming Relation neighbors', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final readService = RelationReadService(objectStore);

    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
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
    await objectStore.createRelationProperty(
      objectTypeId: personTypeId,
      name: 'Lives in',
      targetObjectTypeId: placeTypeId,
      multiple: false,
    );

    final bookProperty = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .single;
    final personProperty = (await objectStore.getObjectType(personTypeId))!
        .properties
        .single;
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final placeId = await objectStore.createObject(
      objectTypeId: placeTypeId,
      title: 'Paris',
    );

    await objectStore.setRelation(
      objectId: bookId,
      property: bookProperty,
      targetObjectIds: [personId],
    );
    await objectStore.setRelation(
      objectId: personId,
      property: personProperty,
      targetObjectIds: [placeId],
    );

    final neighborhood = await readService.neighborhood(
      workspaceId: workspaceId,
      objectTypeId: personTypeId,
      objectId: personId,
    );

    expect(neighborhood.isEmpty, isFalse);
    expect(neighborhood.outgoing, hasLength(1));
    expect(neighborhood.outgoing.single.property.name, 'Lives in');
    expect(neighborhood.outgoing.single.targetObject.id, placeId);
    expect(neighborhood.backlinks, hasLength(1));
    expect(neighborhood.backlinks.single.property.name, 'Author');
    expect(neighborhood.backlinks.single.sourceObject.id, bookId);
  });

  test('neighborhood is empty for an Object with no Relation edges', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final readService = RelationReadService(objectStore);

    final noteTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final noteId = await objectStore.createObject(
      objectTypeId: noteTypeId,
      title: 'Standalone',
    );

    final neighborhood = await readService.neighborhood(
      workspaceId: workspaceId,
      objectTypeId: noteTypeId,
      objectId: noteId,
    );

    expect(neighborhood.isEmpty, isTrue);
    expect(neighborhood.outgoing, isEmpty);
    expect(neighborhood.backlinks, isEmpty);
  });
}
