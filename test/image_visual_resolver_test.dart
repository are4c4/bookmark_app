import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/image_visual_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('managed Image visual exposes persisted geometry without decoding bytes',
      () async {
    final directory = await Directory.systemTemp.createTemp('image_visual_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/managed.img');
    await managedFile.writeAsBytes(const <int>[1, 2, 3]);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final service = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: defaultsStore,
    );
    final definition = await service.ensureDefinition(workspaceId);
    final imageObject = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      originalFilename: 'managed.img',
      pixelWidth: 600,
      pixelHeight: 1200,
    );

    final visual = await ImageVisualResolver(objectStore).resolveManaged(
      imageObjectTypeId: definition.objectType.id,
      imageObjectId: imageObject.id,
    );

    expect(visual?.imageObjectId, imageObject.id);
    expect(visual?.filePath, managedFile.path);
    expect(visual?.pixelWidth, 600);
    expect(visual?.pixelHeight, 1200);
    expect(visual?.aspectRatio, .5);
  });

  test('missing persisted geometry falls back to managed image bytes', () async {
    final directory =
        await Directory.systemTemp.createTemp('image_visual_probe_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/managed.png');
    await managedFile.writeAsBytes(
      image.encodePng(image.Image(width: 7, height: 5)),
    );

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    final imageObject = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      originalFilename: 'managed.png',
    );

    final visual = await ImageVisualResolver(objectStore).resolveManaged(
      imageObjectTypeId: definition.objectType.id,
      imageObjectId: imageObject.id,
    );

    expect(visual?.pixelWidth, 7);
    expect(visual?.pixelHeight, 5);
    expect(visual?.aspectRatio, closeTo(7 / 5, .0001));

    final reloaded = await objectStore.listObjects(definition.objectType.id);
    final stored = reloaded.singleWhere((item) => item.id == imageObject.id);
    expect(stored.values[definition.pixelWidthProperty.id], isNull);
    expect(stored.values[definition.pixelHeightProperty.id], isNull);
  });

  test('profile-relative Image file resolves against the active profile root',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('image_visual_relative_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/photos/legacy.img');
    await managedFile.parent.create(recursive: true);
    await managedFile.writeAsBytes(const <int>[4, 5, 6]);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    final imageObject = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'photos/legacy.img',
      originalFilename: 'legacy.img',
      pixelWidth: 320,
      pixelHeight: 240,
    );

    final visual = await ImageVisualResolver(
      objectStore,
      pathResolver: ProfilePathResolver(directory.path),
    ).resolveManaged(
      imageObjectTypeId: definition.objectType.id,
      imageObjectId: imageObject.id,
    );

    expect(visual?.imageObjectId, imageObject.id);
    expect(visual?.filePath, managedFile.path);
    expect(visual?.aspectRatio, closeTo(4 / 3, .0001));
  });

  test('missing managed file fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    final imageObject = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/definitely/missing/bookmark-image.png',
      pixelWidth: 100,
      pixelHeight: 100,
    );

    expect(
      await ImageVisualResolver(objectStore).resolveManaged(
        imageObjectTypeId: definition.objectType.id,
        imageObjectId: imageObject.id,
      ),
      isNull,
    );
  });

  test('partial invalid persisted geometry uses one decoded dimension pair',
      () async {
    final directory = await Directory.systemTemp.createTemp('image_visual_bad_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/managed.png');
    await managedFile.writeAsBytes(
      image.encodePng(image.Image(width: 9, height: 4)),
    );

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    final imageObject = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      pixelWidth: 300,
      pixelHeight: 200,
    );
    await objectStore.setPropertyValue(
      objectId: imageObject.id,
      property: definition.pixelWidthProperty,
      value: 1.5,
    );

    final visual = await ImageVisualResolver(objectStore).resolveManaged(
      imageObjectTypeId: definition.objectType.id,
      imageObjectId: imageObject.id,
    );
    expect(visual, isNotNull);
    expect(visual?.pixelWidth, 9);
    expect(visual?.pixelHeight, 4);
    expect(visual?.aspectRatio, closeTo(9 / 4, .0001));
  });
}
