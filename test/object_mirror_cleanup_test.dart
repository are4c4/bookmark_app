import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleted legacy tags do not leave orphan Tag objects or links', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(database: database, objectStore: objectStore);
    final bridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
    );

    await database.customStatement("INSERT INTO tags(name) VALUES ('一時タグ')");
    final tagId = (await database.customSelect(
      "SELECT id FROM tags WHERE name = '一時タグ'",
    ).getSingle())
        .read<int>('id');
    await bridge.syncLegacyTags(workspaceId);

    final tagType = await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
    );
    expect(await objectStore.listObjects(tagType!.id), hasLength(1));

    await database.customStatement('DELETE FROM tags WHERE id = ?', [tagId]);
    await bridge.syncLegacyTags(workspaceId);

    expect(await objectStore.listObjects(tagType.id), isEmpty);
    final links = await database.customSelect(
      'SELECT object_id FROM tag_object_links WHERE workspace_id = ?',
      variables: [Variable<int>(workspaceId)],
    ).get();
    expect(links, isEmpty);
  });

  test('workspace removal and photo deletion clean mirrored objects and Relations', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(database: database, objectStore: objectStore);
    final tagBridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
    );
    final bridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
      tagBridge: tagBridge,
    );

    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/temp.jpg', '一時画像')",
    );
    final photoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photo/temp.jpg'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://cleanup.example', '一時ブックマーク')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://cleanup.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      [bookmarkId, workspaceId],
    );

    await bridge.syncAll(workspaceId);

    final imageType = await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    );
    final bookmarkType = await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    );
    final imageObjects = await objectStore.listObjects(imageType!.id);
    expect(imageObjects, hasLength(1));
    expect(await objectStore.listObjects(bookmarkType!.id), hasLength(1));

    final noteTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    await objectStore.createRelationProperty(
      objectTypeId: noteTypeId,
      name: 'Image',
      targetObjectTypeId: imageType.id,
      multiple: false,
    );
    final imageProperty =
        (await objectStore.getObjectType(noteTypeId))!.properties.single;
    final noteId = await objectStore.createObject(
      objectTypeId: noteTypeId,
      title: 'Keeps a reference',
    );
    await objectStore.setRelation(
      objectId: noteId,
      property: imageProperty,
      targetObjectIds: [imageObjects.single.id],
    );

    await database.customStatement(
      'DELETE FROM bookmark_workspace WHERE bookmark_id = ? AND workspace_id = ?',
      [bookmarkId, workspaceId],
    );
    await database.customStatement('DELETE FROM photos WHERE id = ?', [photoId]);
    await bridge.syncAll(workspaceId);

    expect(await objectStore.listObjects(imageType.id), isEmpty);
    expect(await objectStore.listObjects(bookmarkType.id), isEmpty);
    final note = (await objectStore.listObjects(noteTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(note.values[imageProperty.id]).objectIds,
      isEmpty,
    );
    final photoLinks = await database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE workspace_id = ?',
      variables: [Variable<int>(workspaceId)],
    ).get();
    final bookmarkLinks = await database.customSelect(
      'SELECT object_id FROM bookmark_object_links WHERE workspace_id = ?',
      variables: [Variable<int>(workspaceId)],
    ).get();
    expect(photoLinks, isEmpty);
    expect(bookmarkLinks, isEmpty);
  });
}
