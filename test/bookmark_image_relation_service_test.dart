import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_image_relation_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark Image service writes canonical Relations without BookmarkPhotos',
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
      "INSERT INTO bookmarks(url, title) VALUES ('https://canonical-images.example', 'Bookmark')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://canonical-images.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );
    await bridge.syncAll(workspaceId);

    final images = ImageObjectService(
      systemObjects: systemStore,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final imageA = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'images/a.png',
      title: 'Image A',
      originalFilename: 'a.png',
    );
    final imageB = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'images/b.png',
      title: 'Image B',
      originalFilename: 'b.png',
    );
    final imageC = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'images/c.png',
      title: 'Image C',
      originalFilename: 'c.png',
    );

    final service = BookmarkImageRelationService(database);
    var state = await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    );
    expect(state, isNotNull);
    expect(state!.selectedImages, isEmpty);
    expect(state.validCoverImageObjectId, isNull);

    await service.saveImages(
      state: state,
      selectedObjectIds: <int>[imageA.id, imageB.id],
    );
    state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(
      state.images.selectedObjectIds,
      <int>[imageA.id, imageB.id],
    );

    // Legacy cover behavior is preserved: setting a cover that is not already
    // related also adds it to the multi-image Relation atomically.
    await service.setCover(state: state, imageObjectId: imageC.id);
    state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(
      state.images.selectedObjectIds,
      <int>[imageA.id, imageB.id, imageC.id],
    );
    expect(state.validCoverImageObjectId, imageC.id);

    // Detaching the current cover clears Cover Image in the same transaction.
    await service.detachImage(state: state, imageObjectId: imageC.id);
    state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds, <int>[imageA.id, imageB.id]);
    expect(state.validCoverImageObjectId, isNull);

    final legacyLinkCount = (await database.customSelect(
      'SELECT COUNT(*) AS count FROM bookmark_photos WHERE bookmark_id = ?',
      variables: [Variable<int>(bookmarkId)],
    ).getSingle())
        .read<int>('count');
    expect(legacyLinkCount, 0);

    // The production compatibility bridge may run again after a user mutation.
    // Native canonical selections must remain authoritative for their subset.
    await bridge.syncAll(workspaceId);
    state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds, <int>[imageA.id, imageB.id]);
    expect(state.validCoverImageObjectId, isNull);

    await service.setCover(state: state, imageObjectId: imageA.id);
    state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    await service.saveImages(
      state: state,
      selectedObjectIds: <int>[imageB.id],
    );
    state = (await service.load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    ))!;
    expect(state.images.selectedObjectIds, <int>[imageB.id]);
    expect(state.validCoverImageObjectId, isNull);
  });
}
