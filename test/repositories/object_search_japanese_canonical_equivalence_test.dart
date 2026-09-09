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

  test(
    'canonical Search matches composed decomposed and half-width Katakana',
    () async {
      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Japanese canonical Katakana',
      );
      final decomposedId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'カ\u3099イド',
      );
      final precomposedId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'ギター',
      );

      await search.rebuildWorkspace(workspaceId);

      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'ガイド',
        )).map((hit) => hit.objectId),
        [decomposedId],
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'ｶﾞｲﾄﾞ',
        )).map((hit) => hit.objectId),
        [decomposedId],
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'キ\u3099ター',
        )).map((hit) => hit.objectId),
        [precomposedId],
      );
    },
  );

  test(
    'canonical Search matches Hiragana dakuten and handakuten both ways',
    () async {
      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Japanese canonical Hiragana',
      );
      final precomposedId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'がくせい',
      );
      final decomposedId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'は\u309aん',
      );

      await search.rebuildWorkspace(workspaceId);

      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'か\u3099くせい',
        )).map((hit) => hit.objectId),
        [precomposedId],
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'ぱん',
        )).map((hit) => hit.objectId),
        [decomposedId],
      );
    },
  );

  test('canonical equivalence preserves mixed-query AND and Latin prefix semantics', () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Japanese mixed canonical',
    );
    final matchingId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Natsume カ\u3099イド',
    );
    await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Soseki カ\u3099イド',
    );
    await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Object Search',
    );

    await search.rebuildWorkspace(workspaceId);

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'nats ガイド',
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
