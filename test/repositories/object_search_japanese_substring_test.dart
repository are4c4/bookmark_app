import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late ObjectSearchRepository search;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    objectStore = ObjectStore(store);
    search = ObjectSearchRepository(store);
  });

  test('matches Japanese text from inside a unicode61 token', () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Japanese',
    );
    final sosekiId = await objectStore.createObject(
      objectTypeId: typeId,
      title: '夏目漱石',
    );
    final universityId = await objectStore.createObject(
      objectTypeId: typeId,
      title: '北海道大学',
    );
    final appleId = await objectStore.createObject(
      objectTypeId: typeId,
      title: '青りんご',
    );

    await search.rebuildWorkspace(workspaceId);

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: '漱石',
      )).map((hit) => hit.objectId),
      [sosekiId],
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: '大学',
      )).map((hit) => hit.objectId),
      [universityId],
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'りんご',
      )).map((hit) => hit.objectId),
      [appleId],
    );

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: '夏目',
      )).map((hit) => hit.objectId),
      [sosekiId],
    );
  });

  test('keeps non-CJK terms prefix-only and mixed queries ANDed', () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Mixed',
    );
    final matchingId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Natsume 夏目漱石',
    );
    await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Natsume 夏目金之助',
    );
    await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Object Search',
    );

    await search.rebuildWorkspace(workspaceId);

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'natsume 漱石',
      )).map((hit) => hit.objectId),
      [matchingId],
    );
    expect(
      await search.search(workspaceId: workspaceId, rawQuery: 'ject'),
      isEmpty,
    );
  });

  test(
    'Japanese fallback preserves workspace and ObjectType isolation',
    () async {
      final localTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Local',
      );
      final localId = await objectStore.createObject(
        objectTypeId: localTypeId,
        title: '北海道大学',
      );
      final otherLocalTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Other local type',
      );
      await objectStore.createObject(
        objectTypeId: otherLocalTypeId,
        title: '東北大学',
      );

      final otherWorkspace = await database
          .into(database.workspaces)
          .insert(WorkspacesCompanion.insert(name: 'Other'));
      final remoteTypeId = await objectStore.createObjectType(
        workspaceId: otherWorkspace,
        name: 'Remote',
      );
      await objectStore.createObject(objectTypeId: remoteTypeId, title: '京都大学');

      await search.rebuildWorkspace(workspaceId);
      await search.rebuildWorkspace(otherWorkspace);

      expect(
        (await search.search(
          workspaceId: workspaceId,
          objectTypeId: localTypeId,
          rawQuery: '大学',
        )).map((hit) => hit.objectId),
        [localId],
      );
    },
  );
}
