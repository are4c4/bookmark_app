import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy-mirrored Image deletion detaches canonical Relations and clears legacy Person photo', () async {
    final root = await Directory.systemTemp.createTemp(
      'legacy_image_delete_relation_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final photoDirectory = Directory('${root.path}/photos');
    await photoDirectory.create(recursive: true);
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
      photoStorage: PhotoStorageService(
        photoDirectoryPath: photoDirectory.path,
      ),
    );

    final managedFile = File('${photoDirectory.path}/related.png');
    await managedFile.writeAsBytes(const <int>[1, 2, 3]);
    final photoId = await database.addPhoto(path: managedFile.path);
    final legacyPersonId = await database.createPerson('Legacy person');
    await database.customStatement(
      'UPDATE people SET profile_photo_id = ? WHERE id = ?',
      [photoId, legacyPersonId],
    );

    await CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      tagBridge: TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
      ),
    ).syncAll(workspaceId);

    final imageType = (await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    final image = (await objectStore.listObjects(imageType.id)).single;

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final relationPropertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Image',
      targetObjectTypeId: imageType.id,
      multiple: false,
    );
    final sourceType = (await objectStore.getObjectType(sourceTypeId))!;
    final relationProperty = sourceType.properties.singleWhere(
      (property) => property.id == relationPropertyId,
    );
    final sourceObjectId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source object',
    );
    await services.relationMutations.setRelation(
      objectId: sourceObjectId,
      property: relationProperty,
      targetObjectIds: <int>[image.id],
    );
    expect(
      await RelationReadService(objectStore).outgoing(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: sourceObjectId,
      ),
      hasLength(1),
    );

    await services.relationMutations.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: imageType.id,
      objectId: image.id,
    );

    expect(
      await RelationReadService(objectStore).outgoing(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: sourceObjectId,
      ),
      isEmpty,
    );
    expect(
      await database
          .customSelect('SELECT id FROM photos WHERE id = $photoId')
          .get(),
      isEmpty,
    );
    expect(
      await database
          .customSelect(
            'SELECT id FROM people '
            'WHERE id = $legacyPersonId AND profile_photo_id IS NULL',
          )
          .get(),
      hasLength(1),
    );
    expect(await managedFile.exists(), isFalse);
  });
}
