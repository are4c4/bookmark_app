import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upgrade bootstrap converges existing mirrored Bookmark Tags when Weblink Tags schema is absent', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final tagId = await _createTag(database, 'Existing');
    final bookmarkId = await _createBookmark(
      database,
      workspaceId: workspaceId,
      url: 'https://example.com/existing',
      title: 'Existing bookmark',
    );
    await _attachLegacyTag(database, bookmarkId: bookmarkId, tagId: tagId);

    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    // Simulate an existing workspace created by a version before Weblink Tags
    // convergence: mirrored Bookmark + Bookmark->Weblink already exist, but the
    // canonical Weblink Tags Property has never been initialized.
    await sync.coreBridge.syncAll(workspaceId);
    await sync.bookmarkWeblinkBridge.syncWorkspace(workspaceId);
    final beforeType = await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    expect(beforeType, isNotNull);
    expect(
      beforeType!.properties.where((property) => property.name == 'Tags'),
      isEmpty,
    );

    await sync.syncWorkspace(workspaceId);

    final tagObjectId = await sync.tagBridge.objectIdForLegacyTag(
      workspaceId,
      tagId,
    );
    expect(tagObjectId, isNotNull);
    expect(await _canonicalTagIds(sync, workspaceId), <int>[tagObjectId!]);
  });

  test('canonical empty Tags survive later compatibility resync', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final tagId = await _createTag(database, 'Legacy');
    final bookmarkId = await _createBookmark(
      database,
      workspaceId: workspaceId,
      url: 'https://example.com/clear',
      title: 'Clear canonical Tags',
    );
    await _attachLegacyTag(database, bookmarkId: bookmarkId, tagId: tagId);

    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);
    await sync.syncWorkspace(workspaceId);
    expect(await _canonicalTagIds(sync, workspaceId), hasLength(1));

    final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    final tags = weblinkType.properties.singleWhere(
      (property) => property.name == 'Tags',
    );
    final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
    final genericStore = GenericDatabaseStore(database);
    final mutations = RelationMutationService(
      objectStore: sync.objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: sync.objectStore,
      ),
    );
    await mutations.setRelation(
      objectId: weblink.id,
      property: tags,
      targetObjectIds: const <int>[],
    );

    await sync.syncWorkspace(workspaceId);

    expect(await _canonicalTagIds(sync, workspaceId), isEmpty);
  });
}

Future<int> _createTag(AppDatabase database, String name) async {
  await database.customStatement('INSERT INTO tags(name) VALUES (?)', <Object>[
    name,
  ]);
  return (await database
          .customSelect(
            'SELECT id FROM tags WHERE name = ?',
            variables: <Variable<Object>>[Variable<String>(name)],
          )
          .getSingle())
      .read<int>('id');
}

Future<int> _createBookmark(
  AppDatabase database, {
  required int workspaceId,
  required String url,
  required String title,
}) async {
  await database.customStatement(
    'INSERT INTO bookmarks(url, title) VALUES (?, ?)',
    <Object>[url, title],
  );
  final bookmarkId =
      (await database
              .customSelect(
                'SELECT id FROM bookmarks WHERE title = ? ORDER BY id DESC LIMIT 1',
                variables: <Variable<Object>>[Variable<String>(title)],
              )
              .getSingle())
          .read<int>('id');
  await database.customStatement(
    'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
    <Object>[bookmarkId, workspaceId],
  );
  return bookmarkId;
}

Future<void> _attachLegacyTag(
  AppDatabase database, {
  required int bookmarkId,
  required int tagId,
}) => database.customStatement(
  'INSERT INTO bookmark_tags(bookmark_id, tag_id) VALUES (?, ?)',
  <Object>[bookmarkId, tagId],
);

Future<List<int>> _canonicalTagIds(
  ObjectSyncService sync,
  int workspaceId,
) async {
  final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
    workspaceId: workspaceId,
    systemKey: WeblinkObjectService.systemKey,
  ))!;
  final tags = weblinkType.properties.singleWhere(
    (property) => property.name == 'Tags',
  );
  final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
  return ObjectRelationValue.fromJson(weblink.values[tags.id]).objectIds;
}
