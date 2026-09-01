import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relation writes create outgoing edges and backlinks', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));

    final personTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: '人物',
    );
    final bookTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: '本',
    );
    final authorPropertyId = await store.createRelationProperty(
      objectTypeId: bookTypeId,
      name: '著者',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final authorProperty = (await store.getObjectType(bookTypeId))!
        .properties
        .firstWhere((property) => property.id == authorPropertyId);

    final personId = await store.createObject(
      objectTypeId: personTypeId,
      title: '著者A',
    );
    final bookId = await store.createObject(
      objectTypeId: bookTypeId,
      title: '本A',
    );

    await store.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: [personId],
    );

    final outgoing = await store.outgoingRelations(bookId);
    final backlinks = await store.backlinks(personId);
    expect(outgoing, hasLength(1));
    expect(outgoing.single.sourceObjectId, bookId);
    expect(outgoing.single.targetObjectId, personId);
    expect(outgoing.single.propertyId, authorPropertyId);
    expect(backlinks, hasLength(1));
    expect(backlinks.single.sourceObjectId, bookId);
  });

  test('changing a relation replaces stale backlink edges', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));

    final tagTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'タグ',
    );
    final parentPropertyId = await store.createRelationProperty(
      objectTypeId: tagTypeId,
      name: 'Parent',
      targetObjectTypeId: tagTypeId,
      multiple: false,
    );
    final parentProperty = (await store.getObjectType(tagTypeId))!
        .properties
        .firstWhere((property) => property.id == parentPropertyId);

    final firstParent = await store.createObject(
      objectTypeId: tagTypeId,
      title: '親1',
    );
    final secondParent = await store.createObject(
      objectTypeId: tagTypeId,
      title: '親2',
    );
    final child = await store.createObject(
      objectTypeId: tagTypeId,
      title: '子',
    );

    await store.setRelation(
      objectId: child,
      property: parentProperty,
      targetObjectIds: [firstParent],
    );
    await store.setRelation(
      objectId: child,
      property: parentProperty,
      targetObjectIds: [secondParent],
    );

    expect(await store.backlinks(firstParent), isEmpty);
    final backlinks = await store.backlinks(secondParent);
    expect(backlinks, hasLength(1));
    expect(backlinks.single.sourceObjectId, child);
  });

  test('relation index can be rebuilt from existing JSON values', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final generic = GenericDatabaseStore(database);
    final store = ObjectStore(generic);

    final targetTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final sourceTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final propertyId = await store.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Related',
      targetObjectTypeId: targetTypeId,
    );
    final targetId = await store.createObject(
      objectTypeId: targetTypeId,
      title: 'Target A',
    );
    final sourceId = await store.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source A',
    );

    // Simulates a relation saved before the normalized edge index existed.
    await generic.setValue(
      recordId: sourceId,
      propertyId: propertyId,
      value: [targetId],
    );
    expect(await store.backlinks(targetId), isEmpty);

    await store.rebuildRelationIndex(sourceTypeId);

    final backlinks = await store.backlinks(targetId);
    expect(backlinks, hasLength(1));
    expect(backlinks.single.sourceObjectId, sourceId);
  });
}
