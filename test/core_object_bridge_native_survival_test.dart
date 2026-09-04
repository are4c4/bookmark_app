import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy cleanup preserves native Image and Bookmark Objects', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
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

    await bridge.syncAll(workspaceId);
    final imageType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    final bookmarkType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    ))!;
    final nativeImageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Native image',
    );
    final nativeBookmarkId = await objectStore.createObject(
      objectTypeId: bookmarkType.id,
      title: 'Native bookmark',
    );

    await bridge.syncAll(workspaceId);
    expect(
      (await objectStore.listObjects(imageType.id)).map((object) => object.id),
      contains(nativeImageId),
    );
    expect(
      (await objectStore.listObjects(bookmarkType.id)).map((object) => object.id),
      contains(nativeBookmarkId),
    );

    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('legacy.jpg', 'Legacy image')",
    );
    final photoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'legacy.jpg'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://legacy.example', 'Legacy bookmark')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://legacy.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );
    await bridge.syncAll(workspaceId);

    final legacyPhotoProperty = imageType.properties.singleWhere(
      (property) => property.name == 'Legacy Photo ID',
    );
    final legacyBookmarkProperty = bookmarkType.properties.singleWhere(
      (property) => property.name == 'Legacy Bookmark ID',
    );
    final mirroredImageId = (await objectStore.listObjects(imageType.id))
        .singleWhere((object) => object.values[legacyPhotoProperty.id] == photoId)
        .id;
    final mirroredBookmarkId = (await objectStore.listObjects(bookmarkType.id))
        .singleWhere(
          (object) => object.values[legacyBookmarkProperty.id] == bookmarkId,
        )
        .id;

    await database.customStatement(
      'DELETE FROM bookmarks WHERE id = ?',
      <Object>[bookmarkId],
    );
    await database.customStatement(
      'DELETE FROM photos WHERE id = ?',
      <Object>[photoId],
    );
    await bridge.syncAll(workspaceId);

    final imageIds =
        (await objectStore.listObjects(imageType.id)).map((object) => object.id);
    final bookmarkIds =
        (await objectStore.listObjects(bookmarkType.id)).map((object) => object.id);
    expect(imageIds, contains(nativeImageId));
    expect(imageIds, isNot(contains(mirroredImageId)));
    expect(bookmarkIds, contains(nativeBookmarkId));
    expect(bookmarkIds, isNot(contains(mirroredBookmarkId)));
  });
}
