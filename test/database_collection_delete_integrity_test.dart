import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit self-target collection does not block deleting its Database',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final store = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Self collection',
    );
    await store.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: databaseId,
      ),
    );

    await objectStore.deleteObjectType(databaseId);

    expect(await genericStore.getDatabase(databaseId), isNull);
    expect(await store.readEffective(databaseId), isNull);
  });

  test('target ObjectType deletion is blocked while another Database uses it',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final store = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final collectionId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Collection',
    );
    final targetId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    await store.write(
      DatabaseCollectionDefinition(
        databaseId: collectionId,
        workspaceId: workspaceId,
        targetObjectTypeId: targetId,
      ),
    );

    await expectLater(objectStore.deleteObjectType(targetId), throwsA(anything));

    expect(await objectStore.getObjectType(targetId), isNotNull);
    expect((await store.readEffective(collectionId))?.targetObjectTypeId, targetId);
  });
}
