import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relation Property creation rejects a missing target ObjectType', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));

    final bookTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );

    await expectLater(
      store.createRelationProperty(
        objectTypeId: bookTypeId,
        name: 'Author',
        targetObjectTypeId: 999999,
      ),
      throwsArgumentError,
    );

    expect((await store.getObjectType(bookTypeId))!.properties, isEmpty);
  });

  test('relation Property creation rejects cross-workspace targets', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceA = await workspaceStore.initialize();
    final workspaceB = await workspaceStore.createWorkspace('Other');
    final store = ObjectStore(GenericDatabaseStore(database));

    final bookTypeId = await store.createObjectType(
      workspaceId: workspaceA,
      name: 'Book',
    );
    final personTypeId = await store.createObjectType(
      workspaceId: workspaceB,
      name: 'Person',
    );

    await expectLater(
      store.createRelationProperty(
        objectTypeId: bookTypeId,
        name: 'Author',
        targetObjectTypeId: personTypeId,
      ),
      throwsArgumentError,
    );

    expect((await store.getObjectType(bookTypeId))!.properties, isEmpty);
  });
}
