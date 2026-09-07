import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native Bookmark Image Relations survive legacy compatibility sync',
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
    final mutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    final reads = RelationReadService(objectStore);

    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photo/legacy.jpg', 'Legacy')",
    );
    final legacyPhotoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photo/legacy.jpg'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES ('https://native-image.example', 'Bookmark')",
    );
    final bookmarkId = (await database.customSelect(
      "SELECT id FROM bookmarks WHERE url = 'https://native-image.example'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[bookmarkId, workspaceId],
    );
    await database.customStatement(
      'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
      <Object>[bookmarkId, legacyPhotoId],
    );

    await bridge.syncAll(workspaceId);

    final bookmarkType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    ))!;
    final imageType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    final imagesProperty = bookmarkType.properties.singleWhere(
      (property) => property.name == 'Images',
    );
    final coverProperty = bookmarkType.properties.singleWhere(
      (property) => property.name == 'Cover Image',
    );
    final bookmarkObjectId = (await database.customSelect(
      'SELECT object_id FROM bookmark_object_links WHERE workspace_id = ? AND bookmark_id = ?',
      variables: [Variable<int>(workspaceId), Variable<int>(bookmarkId)],
    ).getSingle())
        .read<int>('object_id');
    final legacyImageObjectId = (await database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
      variables: [
        Variable<int>(workspaceId),
        Variable<int>(legacyPhotoId),
      ],
    ).getSingle())
        .read<int>('object_id');

    final nativeImage = await ImageObjectService(
      systemObjects: systemStore,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    ).findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'images/native-only.png',
      title: 'Native image',
      originalFilename: 'native-only.png',
    );
    expect(nativeImage.objectTypeId, imageType.id);

    await mutations.setRelation(
      objectId: bookmarkObjectId,
      property: imagesProperty,
      targetObjectIds: <int>[legacyImageObjectId, nativeImage.id],
    );
    await mutations.setRelation(
      objectId: bookmarkObjectId,
      property: coverProperty,
      targetObjectIds: <int>[nativeImage.id],
    );

    // A compatibility sync may refresh the legacy-mapped subset, but it must
    // not erase first-class Image targets that legacy BookmarkPhotos cannot
    // represent. Native Cover Image is likewise canonical once selected.
    await bridge.syncAll(workspaceId);

    Future<List<ResolvedOutgoingRelation>> outgoing() => reads.outgoing(
          sourceObjectTypeId: bookmarkType.id,
          sourceObjectId: bookmarkObjectId,
        );

    var relations = await outgoing();
    expect(
      relations
          .where((item) => item.property.id == imagesProperty.id)
          .map((item) => item.targetObject.id)
          .toSet(),
      <int>{legacyImageObjectId, nativeImage.id},
    );
    expect(
      relations
          .where((item) => item.property.id == coverProperty.id)
          .single
          .targetObject
          .id,
      nativeImage.id,
    );

    // Removing a legacy BookmarkPhoto removes only that mapped subset on the
    // next sync. The native relation and cover remain intact.
    await database.customStatement(
      'DELETE FROM bookmark_photos WHERE bookmark_id = ? AND photo_id = ?',
      <Object>[bookmarkId, legacyPhotoId],
    );
    await bridge.syncAll(workspaceId);

    relations = await outgoing();
    expect(
      relations
          .where((item) => item.property.id == imagesProperty.id)
          .map((item) => item.targetObject.id)
          .toList(growable: false),
      <int>[nativeImage.id],
    );
    expect(
      relations
          .where((item) => item.property.id == coverProperty.id)
          .single
          .targetObject
          .id,
      nativeImage.id,
    );
  });
}
