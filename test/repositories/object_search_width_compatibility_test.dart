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
    'canonical Search matches Katakana across full and half width',
    () async {
      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Japanese',
      );
      final fullWidthId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'カタカナ',
      );
      final halfWidthId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'ﾊﾝｶｸ',
      );
      final voicedId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'ガイド',
      );

      await search.rebuildWorkspace(workspaceId);

      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'ｶﾀｶﾅ',
        )).map((hit) => hit.objectId),
        [fullWidthId],
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'ハンカク',
        )).map((hit) => hit.objectId),
        [halfWidthId],
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'ｶﾞｲﾄﾞ',
        )).map((hit) => hit.objectId),
        [voicedId],
      );
    },
  );

  test(
    'width-compatible CJK fallback preserves mixed-query AND semantics',
    () async {
      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Mixed',
      );
      final matchingId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Natsume カタカナ',
      );
      await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Soseki カタカナ',
      );
      await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Object Search',
      );

      await search.rebuildWorkspace(workspaceId);

      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'nats ｶﾀｶﾅ',
        )).map((hit) => hit.objectId),
        [matchingId],
      );
      expect(
        await search.search(workspaceId: workspaceId, rawQuery: 'ject'),
        isEmpty,
        reason: 'ordinary Latin search must remain prefix-only',
      );
    },
  );

  test(
    'width compatibility does not erase meaningful internal punctuation',
    () async {
      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Punctuation',
      );
      final punctuatedId = await objectStore.createObject(
        objectTypeId: typeId,
        title: '東・京',
      );

      await search.rebuildWorkspace(workspaceId);

      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: '東･京',
        )).map((hit) => hit.objectId),
        [punctuatedId],
      );
      expect(
        await search.search(workspaceId: workspaceId, rawQuery: '東京'),
        isEmpty,
        reason: 'width folding must not delete internal punctuation',
      );
    },
  );
}
