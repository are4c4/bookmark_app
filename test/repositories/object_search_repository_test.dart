import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late ObjectAliasStore aliasStore;
  late ObjectSearchRepository search;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    aliasStore = ObjectAliasStore(genericStore);
    search = ObjectSearchRepository(genericStore);
  });

  test('indexes titles and aliases for user-defined ObjectTypes', () async {
    final peopleType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final booksType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final person = await objectStore.createObject(
      objectTypeId: peopleType,
      title: '夏目漱石',
    );
    final book = await objectStore.createObject(
      objectTypeId: booksType,
      title: 'Kokoro',
    );
    await aliasStore.replaceAliases(
      objectId: person,
      aliases: const ['Natsume Soseki', '夏目金之助'],
    );

    await search.rebuildWorkspace(workspaceId);

    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: '夏目'))
          .map((hit) => hit.objectId),
      contains(person),
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'natsume'))
          .map((hit) => hit.objectId),
      contains(person),
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'kok',
        objectTypeId: booksType,
      ))
          .map((hit) => hit.objectId),
      [book],
    );
    expect(
      await search.search(
        workspaceId: workspaceId,
        rawQuery: 'natsume',
        objectTypeId: booksType,
      ),
      isEmpty,
    );
  });

  test('workspace rebuild and search leave other workspaces isolated', () async {
    final localType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Local',
    );
    final local = await objectStore.createObject(
      objectTypeId: localType,
      title: 'Shared title local',
    );

    final otherWorkspace = await database.into(database.workspaces).insert(
      WorkspacesCompanion.insert(name: 'Other'),
    );
    final otherType = await objectStore.createObjectType(
      workspaceId: otherWorkspace,
      name: 'Other',
    );
    final other = await objectStore.createObject(
      objectTypeId: otherType,
      title: 'Shared title other',
    );

    await search.rebuildWorkspace(workspaceId);
    await search.rebuildWorkspace(otherWorkspace);
    await search.rebuildWorkspace(workspaceId);

    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'shared'))
          .map((hit) => hit.objectId),
      [local],
    );
    expect(
      (await search.search(workspaceId: otherWorkspace, rawQuery: 'shared'))
          .map((hit) => hit.objectId),
      [other],
    );
  });

  test('focused refresh removes stale title and alias tokens only', () async {
    final type = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Thing',
    );
    final focused = await objectStore.createObject(
      objectTypeId: type,
      title: 'Alpha Object',
    );
    final unrelated = await objectStore.createObject(
      objectTypeId: type,
      title: 'Beta Object',
    );
    await aliasStore.addAlias(objectId: focused, alias: 'Legacy Alias');
    await search.rebuildWorkspace(workspaceId);

    await objectStore.renameObject(focused, 'Gamma Object');
    await aliasStore.replaceAliases(
      objectId: focused,
      aliases: const ['Current Alias'],
    );
    await search.refreshObject(focused);

    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'gamma'))
          .map((hit) => hit.objectId),
      contains(focused),
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'current'))
          .map((hit) => hit.objectId),
      contains(focused),
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'alpha'))
          .map((hit) => hit.objectId),
      isNot(contains(focused)),
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'legacy'))
          .map((hit) => hit.objectId),
      isNot(contains(focused)),
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'beta'))
          .map((hit) => hit.objectId),
      contains(unrelated),
    );
  });

  test('focused refresh is idempotent and removes a deleted Object', () async {
    final type = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Thing',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: type,
      title: 'Disposable Object',
    );
    await search.rebuildWorkspace(workspaceId);

    await search.refreshObject(objectId);
    await search.refreshObject(objectId);
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'disposable'))
          .map((hit) => hit.objectId),
      [objectId],
    );

    await objectStore.deleteObject(objectId);
    await search.refreshObject(objectId);
    expect(
      await search.search(workspaceId: workspaceId, rawQuery: 'disposable'),
      isEmpty,
    );
  });
}
