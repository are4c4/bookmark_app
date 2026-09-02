import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relation write rejects a source Object from another ObjectType', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));

    final bookTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final placeTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Place',
    );
    await store.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );

    final placeId = await store.createObject(
      objectTypeId: placeTypeId,
      title: 'Sapporo',
    );
    final personId = await store.createObject(
      objectTypeId: personTypeId,
      title: 'Author',
    );
    final relation = (await store.getObjectType(bookTypeId))!.properties.single;

    await expectLater(
      store.setRelation(
        objectId: placeId,
        property: relation,
        targetObjectIds: [personId],
      ),
      throwsArgumentError,
    );
    expect(await store.outgoingRelations(placeId), isEmpty);
  });

  test('relation write rejects a forged Property source ObjectType', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));

    final bookTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await store.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final bookId = await store.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await store.createObject(
      objectTypeId: personTypeId,
      title: 'Author',
    );
    final stored = (await store.getObjectType(bookTypeId))!.properties.single;
    final forged = ObjectPropertyDefinition(
      id: stored.id,
      objectTypeId: personTypeId,
      name: stored.name,
      type: stored.type,
      sortOrder: stored.sortOrder,
      config: stored.config,
    );

    await expectLater(
      store.setRelation(
        objectId: bookId,
        property: forged,
        targetObjectIds: [personId],
      ),
      throwsArgumentError,
    );
    expect(await store.outgoingRelations(bookId), isEmpty);
  });
}
