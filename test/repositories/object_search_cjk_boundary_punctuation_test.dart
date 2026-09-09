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

  test('CJK fallback ignores only surrounding token punctuation', () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Japanese',
    );
    final universityId = await objectStore.createObject(
      objectTypeId: typeId,
      title: '北海道大学',
    );
    final sosekiId = await objectStore.createObject(
      objectTypeId: typeId,
      title: '夏目漱石',
    );
    await objectStore.createObject(objectTypeId: typeId, title: '東京大学');

    await search.rebuildWorkspace(workspaceId);

    for (final query in const <String>['大学。', '「大学」', '（大学）']) {
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: query,
        )).map((hit) => hit.objectId),
        contains(universityId),
        reason: 'surrounding punctuation should be a CJK fallback boundary',
      );
    }
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: '漱石、',
      )).map((hit) => hit.objectId),
      [sosekiId],
    );
    expect(
      await search.search(workspaceId: workspaceId, rawQuery: '東・京'),
      isEmpty,
      reason: 'punctuation inside a CJK term must not be erased',
    );
  });

  test('punctuated CJK mixed query keeps Latin prefix AND semantics', () async {
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
        rawQuery: 'natsume 「漱石」',
      )).map((hit) => hit.objectId),
      [matchingId],
    );
    expect(
      await search.search(workspaceId: workspaceId, rawQuery: 'ject'),
      isEmpty,
      reason: 'ordinary Latin search must remain prefix-only',
    );
  });
}
