import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target ObjectType deletion is blocked while an incoming Relation exists', () async {
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

    await expectLater(store.deleteObjectType(personTypeId), throwsStateError);
    expect(await store.getObjectType(personTypeId), isNotNull);

    final relation = (await store.getObjectType(bookTypeId))!.properties.single;
    await store.deleteProperty(relation.id);
    await store.deleteObjectType(personTypeId);

    expect(await store.getObjectType(personTypeId), isNull);
  });

  test('self Relation does not block deletion of its own ObjectType', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));

    final tagTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Tag',
    );
    await store.createRelationProperty(
      objectTypeId: tagTypeId,
      name: 'Parent',
      targetObjectTypeId: tagTypeId,
      multiple: false,
    );

    await store.deleteObjectType(tagTypeId);
    expect(await store.getObjectType(tagTypeId), isNull);
  });
}
