import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_image_relation_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Photo attach writes canonical Bookmark Image Relations', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
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
      "INSERT INTO bookmarks(url, title) VALUES ('https://photo-attach.example', 'Bookmark')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://photo-attach.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );
    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/attach.jpg', 'Legacy Photo')",
    );
    final photoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photo/attach.jpg'",
    ).getSingle())
        .read<int>('id');

    await bridge.syncAll(workspaceId);
    final imageObjectId = (await database.customSelect(
      'SELECT object_id FROM photo_object_links '
      'WHERE workspace_id = $workspaceId AND photo_id = $photoId',
    ).getSingle())
        .read<int>('object_id');

    final service = BookmarkImageRelationService(database);
    await service.attachLegacyPhoto(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
      photoId: photoId,
    );

    var state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds, <int>[imageObjectId]);
    expect(state.validCoverImageObjectId, isNull);

    var legacyRow = await database.customSelect(
      'SELECT photo_id, is_cover FROM bookmark_photos '
      'WHERE bookmark_id = $bookmarkId',
    ).getSingle();
    expect(legacyRow.read<int>('photo_id'), photoId);
    expect(legacyRow.read<int>('is_cover'), 0);

    await service.attachLegacyPhoto(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
      photoId: photoId,
      asCover: true,
    );
    state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds, <int>[imageObjectId]);
    expect(state.validCoverImageObjectId, imageObjectId);

    legacyRow = await database.customSelect(
      'SELECT photo_id, is_cover FROM bookmark_photos '
      'WHERE bookmark_id = $bookmarkId',
    ).getSingle();
    expect(legacyRow.read<int>('photo_id'), photoId);
    expect(legacyRow.read<int>('is_cover'), 1);

    // Compatibility sync must preserve the canonical edit because the legacy
    // row is now only a projection of the canonical mapped Image selection.
    await bridge.syncAll(workspaceId);
    state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds, <int>[imageObjectId]);
    expect(state.validCoverImageObjectId, imageObjectId);
  });

  test('legacy Photo attach fails closed without a Photo to Image mapping',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
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
      "INSERT INTO bookmarks(url, title) VALUES ('https://missing-photo-map.example', 'Bookmark')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://missing-photo-map.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );
    await bridge.syncAll(workspaceId);

    final service = BookmarkImageRelationService(database);
    await expectLater(
      service.attachLegacyPhoto(
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
        photoId: 999,
      ),
      throwsStateError,
    );

    final state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds, isEmpty);
    expect(state.validCoverImageObjectId, isNull);
    final legacyCount = (await database.customSelect(
      'SELECT COUNT(*) AS count FROM bookmark_photos '
      'WHERE bookmark_id = $bookmarkId',
    ).getSingle())
        .read<int>('count');
    expect(legacyCount, 0);
  });
}
