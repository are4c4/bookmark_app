import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mirrors workspace bookmarks, image relations and tag relations', () async {
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

    await database.customStatement("INSERT INTO tags(name) VALUES ('数学')");
    final tagId = (await database.customSelect("SELECT id FROM tags WHERE name = '数学'").getSingle())
        .read<int>('id');
    await database.customStatement(
      "INSERT INTO photos(path, title, note) VALUES ('photo/a.jpg', '表紙', 'メモ')",
    );
    final photoId = (await database.customSelect("SELECT id FROM photos WHERE path = 'photo/a.jpg'").getSingle())
        .read<int>('id');
    await database.customStatement(
      "INSERT INTO bookmarks(url, title, description, favorite, rating) VALUES ('https://example.com', '数学資料', '説明', 1, 4)",
    );
    final bookmarkId = (await database.customSelect("SELECT id FROM bookmarks WHERE url = 'https://example.com'").getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      [bookmarkId, workspaceId],
    );
    await database.customStatement(
      'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
      [bookmarkId, photoId],
    );
    await database.customStatement(
      'INSERT INTO bookmark_tags(bookmark_id, tag_id) VALUES (?, ?)',
      [bookmarkId, tagId],
    );

    await bridge.syncAll(workspaceId);
    await bridge.syncAll(workspaceId);

    final imageType = await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    );
    final bookmarkType = await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    );
    expect(imageType, isNotNull);
    expect(bookmarkType, isNotNull);
    final resolvedImageType = imageType!;
    final resolvedBookmarkType = bookmarkType!;

    for (final propertyName in <String>[
      'File',
      'Note',
      'Source URL',
      'Original filename',
      'Content type',
      'Pixel width',
      'Pixel height',
      'Legacy Photo ID',
      'Legacy Tags',
    ]) {
      expect(
        resolvedImageType.properties.where((property) => property.name == propertyName),
        hasLength(1),
        reason: 'Photo mirrors should share the canonical Image definition.',
      );
    }

    final images = await objectStore.listObjects(resolvedImageType.id);
    final bookmarks = await objectStore.listObjects(resolvedBookmarkType.id);
    expect(images, hasLength(1));
    expect(bookmarks, hasLength(1));
    expect(images.single.title, '表紙');
    final fileProperty = resolvedImageType.properties.firstWhere((p) => p.name == 'File');
    final noteProperty = resolvedImageType.properties.firstWhere((p) => p.name == 'Note');
    final filenameProperty =
        resolvedImageType.properties.firstWhere((p) => p.name == 'Original filename');
    expect(images.single.values[fileProperty.id], 'photo/a.jpg');
    expect(images.single.values[noteProperty.id], 'メモ');
    expect(images.single.values[filenameProperty.id], 'a.jpg');
    expect(bookmarks.single.title, '数学資料');

    final imageRelation = resolvedBookmarkType.properties.firstWhere((p) => p.name == 'Images');
    final tagRelation = resolvedBookmarkType.properties.firstWhere((p) => p.name == 'Tags');
    expect(
      ObjectRelationValue.fromJson(bookmarks.single.values[imageRelation.id]).objectIds,
      [images.single.id],
    );

    final tagObjectId = await tagBridge.objectIdForLegacyTag(workspaceId, tagId);
    expect(
      ObjectRelationValue.fromJson(bookmarks.single.values[tagRelation.id]).objectIds,
      [tagObjectId],
    );

    final urlProperty = resolvedBookmarkType.properties.firstWhere((p) => p.name == 'URL');
    final favoriteProperty = resolvedBookmarkType.properties.firstWhere((p) => p.name == 'Favorite');
    expect(bookmarks.single.values[urlProperty.id], 'https://example.com');
    expect(bookmarks.single.values[favoriteProperty.id], true);
  });
}
