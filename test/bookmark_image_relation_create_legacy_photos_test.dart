import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_image_relation_service.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('created Bookmark mirrors selected legacy Photos before canonical save',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();

    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://create-images.example', 'Created Bookmark')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://create-images.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );
    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/create-a.jpg', 'Create A')",
    );
    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/create-b.jpg', 'Create B')",
    );
    final photoAId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photo/create-a.jpg'",
    ).getSingle())
        .read<int>('id');
    final photoBId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photo/create-b.jpg'",
    ).getSingle())
        .read<int>('id');

    // No ObjectSyncService call happens before this mutation. The create-specific
    // service boundary must establish Bookmark/Photo mirrors deterministically
    // instead of waiting for the app's debounced watcher.
    final service = BookmarkImageRelationService(database);
    await service.saveLegacyPhotosAfterCreate(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
      photoIds: <int>[photoAId, photoBId],
      coverPhotoId: photoBId,
    );

    final imageAId = (await database.customSelect(
      'SELECT object_id FROM photo_object_links '
      'WHERE workspace_id = $workspaceId AND photo_id = $photoAId',
    ).getSingle())
        .read<int>('object_id');
    final imageBId = (await database.customSelect(
      'SELECT object_id FROM photo_object_links '
      'WHERE workspace_id = $workspaceId AND photo_id = $photoBId',
    ).getSingle())
        .read<int>('object_id');
    final bookmarkObjectCount = (await database.customSelect(
      'SELECT COUNT(*) AS count FROM bookmark_object_links '
      'WHERE workspace_id = $workspaceId AND bookmark_id = $bookmarkId',
    ).getSingle())
        .read<int>('count');
    expect(bookmarkObjectCount, 1);

    var state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    // #245 does not introduce ordering semantics for the multi-image Relation.
    // The durable invariant is membership plus the explicit single cover.
    expect(state.images.selectedObjectIds.toSet(), <int>{imageAId, imageBId});
    expect(state.validCoverImageObjectId, imageBId);

    final legacyRows = await database.customSelect(
      'SELECT photo_id, is_cover FROM bookmark_photos '
      'WHERE bookmark_id = $bookmarkId ORDER BY photo_id',
    ).get();
    expect(legacyRows, hasLength(2));
    expect(
      legacyRows.map((row) => row.read<int>('photo_id')).toList(),
      <int>[photoAId, photoBId],
    );
    expect(
      legacyRows.map((row) => row.read<int>('is_cover')).toList(),
      <int>[0, 1],
    );

    // Exercise the same immediate + live compatibility sync used by the app.
    // It must preserve the canonical edit rather than rebuilding Relations from
    // stale legacy state.
    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);
    await sync.syncWorkspace(workspaceId);
    state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds.toSet(), <int>{imageAId, imageBId});
    expect(state.validCoverImageObjectId, imageBId);
  });

  test('created Bookmark validates every Photo mapping before Relation mutation',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();

    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://create-invalid-image.example', 'Created Bookmark')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://create-invalid-image.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );
    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/create-valid.jpg', 'Valid')",
    );
    final validPhotoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photo/create-valid.jpg'",
    ).getSingle())
        .read<int>('id');

    final service = BookmarkImageRelationService(database);
    await expectLater(
      service.saveLegacyPhotosAfterCreate(
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
        photoIds: <int>[validPhotoId, 999999],
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

    // Mirror work may create the valid Image, but Relation mutation waits until
    // the complete requested Photo set has passed validation.
    final validPhotoMappingCount = (await database.customSelect(
      'SELECT COUNT(*) AS count FROM photo_object_links '
      'WHERE workspace_id = $workspaceId AND photo_id = $validPhotoId',
    ).getSingle())
        .read<int>('count');
    expect(validPhotoMappingCount, 1);
  });
}
