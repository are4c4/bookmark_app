import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_image_relation_service.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('created Bookmark attaches native canonical Images without legacy Photos',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final imageAId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Native Image A',
    );
    final imageBId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Native Image B',
    );

    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://canonical-create.example', 'Created Bookmark')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://canonical-create.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );

    final service = BookmarkImageRelationService(database);
    final available = await service.searchAvailableImages(
      workspaceId: workspaceId,
      query: 'Native Image',
    );
    expect(
      available.map((result) => result.objectId).toSet(),
      <int>{imageAId, imageBId},
    );

    await service.saveImagesAfterCreate(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
      imageObjectIds: <int>[imageAId, imageBId, imageAId],
      coverImageObjectId: imageBId,
    );

    var state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds.toSet(), <int>{imageAId, imageBId});
    expect(state.validCoverImageObjectId, imageBId);

    final legacyPhotoCount = (await database.customSelect(
      'SELECT COUNT(*) AS count FROM photos',
    ).getSingle())
        .read<int>('count');
    final legacyBookmarkPhotoCount = (await database.customSelect(
      'SELECT COUNT(*) AS count FROM bookmark_photos '
      'WHERE bookmark_id = $bookmarkId',
    ).getSingle())
        .read<int>('count');
    expect(legacyPhotoCount, 0);
    expect(legacyBookmarkPhotoCount, 0);

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

  test('created Bookmark rejects non-Image Object before Relation mutation',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final imageId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Valid Image',
    );
    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: customTypeId,
      title: 'Wrong target',
    );

    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://canonical-invalid.example', 'Created Bookmark')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://canonical-invalid.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );

    final service = BookmarkImageRelationService(database);
    await expectLater(
      service.saveImagesAfterCreate(
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
        imageObjectIds: <int>[imageId, bookId],
      ),
      throwsArgumentError,
    );

    final state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds, isEmpty);
    expect(state.validCoverImageObjectId, isNull);
    final legacyBookmarkPhotoCount = (await database.customSelect(
      'SELECT COUNT(*) AS count FROM bookmark_photos '
      'WHERE bookmark_id = $bookmarkId',
    ).getSingle())
        .read<int>('count');
    expect(legacyBookmarkPhotoCount, 0);
  });
}
