import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/image_visual_resolver.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Photo promotion reuses exact-File native Image without taking ownership',
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
    final images = ImageObjectService(
      systemObjects: systemStore,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final nativeImage = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'photos/shared.jpg',
      title: 'Native before promotion',
      originalFilename: 'shared.jpg',
    );
    await objectStore.setPropertyValue(
      objectId: nativeImage.id,
      property: definition.noteProperty,
      value: 'Native note',
    );

    await database.customStatement(
      "INSERT INTO photos(path, title, note) VALUES ('photos/shared.jpg', 'Legacy shared', 'Legacy note')",
    );
    final photoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photos/shared.jpg'",
    ).getSingle())
        .read<int>('id');
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
    await bridge.syncAll(workspaceId);

    final imageType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    var imageObjects = await objectStore.listObjects(imageType.id);
    expect(imageObjects, hasLength(1));
    expect(imageObjects.single.id, nativeImage.id);
    expect(imageObjects.single.title, 'Native before promotion');

    final legacyIdProperty =
        imageType.properties.singleWhere((property) => property.name == 'Legacy Photo ID');
    final fileProperty =
        imageType.properties.singleWhere((property) => property.name == 'File');
    final noteProperty =
        imageType.properties.singleWhere((property) => property.name == 'Note');
    final filenameProperty = imageType.properties
        .singleWhere((property) => property.name == 'Original filename');
    expect(imageObjects.single.values[legacyIdProperty.id], isNull);
    expect(imageObjects.single.values[fileProperty.id], 'photos/shared.jpg');
    expect(imageObjects.single.values[noteProperty.id], 'Native note');
    expect(imageObjects.single.values[filenameProperty.id], 'shared.jpg');

    final link = await database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
      variables: [
        Variable<int>(workspaceId),
        Variable<int>(photoId),
      ],
    ).getSingle();
    expect(link.read<int>('object_id'), nativeImage.id);

    await database.customStatement(
      'DELETE FROM photos WHERE id = ?',
      <Object>[photoId],
    );
    await bridge.syncAll(workspaceId);

    imageObjects = await objectStore.listObjects(imageType.id);
    expect(imageObjects, hasLength(1));
    expect(imageObjects.single.id, nativeImage.id);
    final remainingLinks = await database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE workspace_id = ?',
      variables: [Variable<int>(workspaceId)],
    ).get();
    expect(remainingLinks, isEmpty);
  });

  test('promoted relative Photo path resolves through the active profile root',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('photo_promotion_relative_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/photos/legacy.jpg');
    await managedFile.parent.create(recursive: true);
    await managedFile.writeAsBytes(const <int>[1, 2, 3]);

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
      "INSERT INTO photos(path, title) VALUES ('photos/legacy.jpg', 'Legacy relative')",
    );

    await bridge.syncAll(workspaceId);

    final imageType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    final promoted = (await objectStore.listObjects(imageType.id)).single;
    final visual = await ImageVisualResolver(
      objectStore,
      pathResolver: ProfilePathResolver(directory.path),
    ).resolveManaged(
      imageObjectTypeId: imageType.id,
      imageObjectId: promoted.id,
    );

    expect(visual, isNotNull);
    expect(visual?.imageObjectId, promoted.id);
    expect(visual?.filePath, managedFile.path);
  });

  test('missing rooted Photo stays unmapped and promotes after file recovery',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo_promotion_missing_retry_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: directory.path,
    );
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
      "INSERT INTO photos(path, title, note) VALUES ('photos/recover.jpg', 'Recover me', 'Legacy context')",
    );
    final photoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photos/recover.jpg'",
    ).getSingle())
        .read<int>('id');

    await bridge.syncAll(workspaceId);

    final imageType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    expect(await objectStore.listObjects(imageType.id), isEmpty);
    expect(
      await database.customSelect(
        'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
        variables: [Variable<int>(workspaceId), Variable<int>(photoId)],
      ).getSingleOrNull(),
      isNull,
    );

    final recoveredFile = File('${directory.path}/photos/recover.jpg');
    await recoveredFile.parent.create(recursive: true);
    await recoveredFile.writeAsBytes(const <int>[9, 8, 7]);

    await bridge.syncAll(workspaceId);
    await bridge.syncAll(workspaceId);

    final images = await objectStore.listObjects(imageType.id);
    expect(images, hasLength(1));
    expect(images.single.title, 'Recover me');
    final legacyIdProperty = imageType.properties
        .singleWhere((property) => property.name == 'Legacy Photo ID');
    final fileProperty =
        imageType.properties.singleWhere((property) => property.name == 'File');
    final noteProperty =
        imageType.properties.singleWhere((property) => property.name == 'Note');
    expect(images.single.values[legacyIdProperty.id], photoId);
    expect(images.single.values[fileProperty.id], 'photos/recover.jpg');
    expect(images.single.values[noteProperty.id], 'Legacy context');

    final links = await database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
      variables: [Variable<int>(workspaceId), Variable<int>(photoId)],
    ).get();
    expect(links, hasLength(1));
    expect(links.single.read<int>('object_id'), images.single.id);
  });
}
