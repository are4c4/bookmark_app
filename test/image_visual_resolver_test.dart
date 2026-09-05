import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/image_visual_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final image = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      originalFilename: 'managed.img',
      pixelWidth: 600,
      pixelHeight: 1200,
    );

    final visual = await ImageVisualResolver(objectStore).resolveManaged(
      imageObjectTypeId: definition.objectType.id,
      imageObjectId: image.id,
    );

    expect(visual?.imageObjectId, image.id);
    expect(visual?.filePath, managedFile.path);
    expect(visual?.pixelWidth, 600);
    expect(visual?.pixelHeight, 1200);
    expect(visual?.aspectRatio, .5);
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
    final image = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/definitely/missing/bookmark-image.png',
      pixelWidth: 100,
      pixelHeight: 100,
    );

    expect(
      await ImageVisualResolver(objectStore).resolveManaged(
        imageObjectTypeId: definition.objectType.id,
        imageObjectId: image.id,
      ),
      isNull,
    );
  });

  test('invalid persisted dimension is ignored while managed file stays usable',
      () async {
    final directory = await Directory.systemTemp.createTemp('image_visual_bad_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/managed.img');
    await managedFile.writeAsBytes(const <int>[7]);

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
    final image = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      pixelWidth: 300,
      pixelHeight: 200,
    );
    await objectStore.setPropertyValue(
      objectId: image.id,
      property: definition.pixelWidthProperty,
      value: 1.5,
    );

    final visual = await ImageVisualResolver(objectStore).resolveManaged(
      imageObjectTypeId: definition.objectType.id,
      imageObjectId: image.id,
    );
    expect(visual, isNotNull);
    expect(visual?.pixelWidth, isNull);
    expect(visual?.pixelHeight, 200);
    expect(visual?.aspectRatio, isNull);
  });
}
