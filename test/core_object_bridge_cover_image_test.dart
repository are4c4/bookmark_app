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
  test('legacy cover syncs to single canonical Cover Image Relation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final bridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
      tagBridge: TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemStore,
      ),
    );

    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/a.jpg', 'A')",
    );
    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/b.jpg', 'B')",
    );
    final photoRows = await database.customSelect(
      "SELECT id, path FROM photos WHERE path IN ('photo/a.jpg', 'photo/b.jpg') ORDER BY path",
    ).get();
    final photoAId = photoRows[0].read<int>('id');
    final photoBId = photoRows[1].read<int>('id');

    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://example.com', 'Example')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://example.com'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );
    await database.customStatement(
      'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
      <Object>[bookmarkId, photoAId],
    );
    await database.customStatement(
      'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 0)',
      <Object>[bookmarkId, photoBId],
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
    final legacyPhotoId = imageType.properties.singleWhere(
      (property) => property.name == 'Legacy Photo ID',
    );
    final imageObjects = await objectStore.listObjects(imageType.id);
    final imageByPhotoId = <int, AppObject>{
      for (final image in imageObjects)
        image.values[legacyPhotoId.id] as int: image,
    };
    final imageAId = imageByPhotoId[photoAId]!.id;
    final imageBId = imageByPhotoId[photoBId]!.id;

    final imagesProperty = bookmarkType.properties.singleWhere(
      (property) => property.name == 'Images',
    );
    final coverProperty = bookmarkType.properties.singleWhere(
      (property) => property.name == 'Cover Image',
    );
    expect(coverProperty.isRelation, isTrue);
    expect(coverProperty.targetObjectTypeId, imageType.id);
    expect(coverProperty.allowsMultipleRelations, isFalse);

    Future<AppObject> bookmarkObject() async {
      final legacyBookmarkId = bookmarkType.properties.singleWhere(
        (property) => property.name == 'Legacy Bookmark ID',
      );
      return (await objectStore.listObjects(bookmarkType.id)).singleWhere(
        (object) => object.values[legacyBookmarkId.id] == bookmarkId,
      );
    }

    var bookmarkObjectValue = await bookmarkObject();
    expect(
      ObjectRelationValue.fromJson(
        bookmarkObjectValue.values[imagesProperty.id],
      ).objectIds,
      <int>[imageAId, imageBId],
    );
    expect(
      ObjectRelationValue.fromJson(
        bookmarkObjectValue.values[coverProperty.id],
      ).objectIds,
      <int>[imageAId],
    );

    await database.customStatement(
      'UPDATE bookmark_photos SET is_cover = 0 WHERE bookmark_id = ?',
      <Object>[bookmarkId],
    );
    await database.customStatement(
      'UPDATE bookmark_photos SET is_cover = 1 WHERE bookmark_id = ? AND photo_id = ?',
      <Object>[bookmarkId, photoBId],
    );
    await bridge.syncAll(workspaceId);

    bookmarkObjectValue = await bookmarkObject();
    expect(
      ObjectRelationValue.fromJson(
        bookmarkObjectValue.values[coverProperty.id],
      ).objectIds,
      <int>[imageBId],
    );

    await database.customStatement(
      'UPDATE bookmark_photos SET is_cover = 0 WHERE bookmark_id = ?',
      <Object>[bookmarkId],
    );
    await bridge.syncAll(workspaceId);

    bookmarkObjectValue = await bookmarkObject();
    expect(
      ObjectRelationValue.fromJson(
        bookmarkObjectValue.values[coverProperty.id],
      ).objectIds,
      isEmpty,
    );
    expect(
      ObjectRelationValue.fromJson(
        bookmarkObjectValue.values[imagesProperty.id],
      ).objectIds.toSet(),
      <int>{imageAId, imageBId},
    );

    await database.customStatement(
      'UPDATE bookmark_photos SET is_cover = 1 WHERE bookmark_id = ?',
      <Object>[bookmarkId],
    );
    await expectLater(
      bridge.syncAll(workspaceId),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('multiple cover photos'),
        ),
      ),
    );

    bookmarkObjectValue = await bookmarkObject();
    expect(
      ObjectRelationValue.fromJson(
        bookmarkObjectValue.values[coverProperty.id],
      ).objectIds,
      isEmpty,
      reason: 'ambiguous legacy cover state must fail closed without rewriting the prior canonical cover',
    );
  });
}
