import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/legacy_photo_bookmark_backlink_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Photo reverse lookup reads canonical Bookmark Image backlinks only',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final bridge = _coreBridge(database);

    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/backlink.jpg', 'Backlink image')",
    );
    final photoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photo/backlink.jpg'",
    ).getSingle())
        .read<int>('id');

    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://backlink-a.example', 'A')",
    );
    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://backlink-b.example', 'B')",
    );
    final bookmarkAId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://backlink-a.example'",
    ).getSingle())
        .read<int>('id');
    final bookmarkBId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://backlink-b.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkAId, workspaceId],
    );
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkBId, workspaceId],
    );
    await database.customStatement(
      'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
      <Object>[bookmarkAId, photoId],
    );
    await database.customStatement(
      'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 0)',
      <Object>[bookmarkBId, photoId],
    );

    await bridge.syncAll(workspaceId);

    final service = LegacyPhotoBookmarkBacklinkService(database);
    expect(
      await service.bookmarkIdsForPhoto(
        workspaceId: workspaceId,
        photoId: photoId,
      ),
      <int>{bookmarkAId, bookmarkBId},
    );

    // Remove the legacy projection after mirroring. Reverse lookup must continue
    // to resolve the canonical Relations rather than scanning bookmark_photos or
    // BookmarkItem.photos. Bookmark A has both Images + Cover Image backlinks,
    // but still appears only once.
    await database.customStatement(
      'DELETE FROM bookmark_photos WHERE photo_id = ?',
      <Object>[photoId],
    );
    expect(
      await service.bookmarkIdsForPhoto(
        workspaceId: workspaceId,
        photoId: photoId,
      ),
      <int>{bookmarkAId, bookmarkBId},
    );
  });

  test('Photo reverse lookup fails closed when Photo has no Image mapping',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final bridge = _coreBridge(database);
    await bridge.ensureSchema();

    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/unmapped.jpg', 'Unmapped')",
    );
    final photoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photo/unmapped.jpg'",
    ).getSingle())
        .read<int>('id');

    final service = LegacyPhotoBookmarkBacklinkService(database);
    await expectLater(
      service.bookmarkIdsForPhoto(
        workspaceId: workspaceId,
        photoId: photoId,
      ),
      throwsStateError,
    );
  });
}

CoreObjectBridge _coreBridge(AppDatabase database) {
  final objectStore = ObjectStore(GenericDatabaseStore(database));
  final systemObjects = SystemObjectStore(
    database: database,
    objectStore: objectStore,
  );
  return CoreObjectBridge(
    database: database,
    objectStore: objectStore,
    systemObjectStore: systemObjects,
    tagBridge: TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    ),
  );
}
