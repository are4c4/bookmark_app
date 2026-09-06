import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global search returns current canonical Objects across ObjectTypes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final search = ObjectGlobalSearchService(genericStore);

    final personType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final bookType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final ada = await objectStore.createObject(
      objectTypeId: personType,
      title: 'Ada SearchToken',
    );
    final book = await objectStore.createObject(
      objectTypeId: bookType,
      title: 'SearchToken Notes',
    );

    await search.rebuildWorkspace(workspaceId);

    final all = await search.search(
      workspaceId: workspaceId,
      rawQuery: 'searchtoken',
    );
    expect(all.map((item) => item.object.id).toSet(), <int>{ada, book});
    expect(all.every((item) => item.hit.objectId == item.object.id), isTrue);
    expect(
      all.every((item) => item.hit.objectTypeId == item.objectType.id),
      isTrue,
    );

    final peopleOnly = await search.search(
      workspaceId: workspaceId,
      rawQuery: 'searchtoken',
      objectTypeId: personType,
    );
    expect(peopleOnly.map((item) => item.object.id), <int>[ada]);
  });

  test('refresh updates title tokens and stale deleted hits fail closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final search = ObjectGlobalSearchService(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Item',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'LegacyGlobalToken',
    );
    await search.rebuildWorkspace(workspaceId);

    await objectStore.renameObject(objectId, 'CurrentGlobalToken');
    await search.refreshObject(objectId);

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'currentglobal',
      ))
          .map((item) => item.object.id),
      <int>[objectId],
    );
    expect(
      await search.search(
        workspaceId: workspaceId,
        rawQuery: 'legacyglobal',
      ),
      isEmpty,
    );

    await objectStore.deleteObject(objectId);
    expect(
      await search.search(
        workspaceId: workspaceId,
        rawQuery: 'currentglobal',
      ),
      isEmpty,
      reason: 'resolver must not return a deleted Object from a stale FTS row',
    );
  });
}
