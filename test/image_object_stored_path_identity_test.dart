import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('managed Image stores profile-relative path and reuses relative identity',
      () async {
    final root = await Directory.systemTemp.createTemp('image_path_identity_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/photos/shared.png');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes(const <int>[1, 2, 3]);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
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

    final first = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      title: 'Managed image',
    );
    final second = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'photos/shared.png',
      title: 'Must reuse',
    );

    expect(second.id, first.id);
    final stored = (await objectStore.listObjects(definition.objectType.id)).single;
    expect(stored.values[definition.fileProperty.id], 'photos/shared.png');
    expect(stored.title, 'Managed image');
  });

  test('relative reimport reuses an older absolute stored Image identity',
      () async {
    final root = await Directory.systemTemp.createTemp('image_path_legacy_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/photos/legacy.png');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes(const <int>[4, 5, 6]);

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
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final legacyId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Legacy absolute',
    );
    await objectStore.setPropertyValue(
      objectId: legacyId,
      property: definition.fileProperty,
      value: managed.path,
    );

    final reused = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'photos/legacy.png',
      title: 'Must not duplicate',
    );

    expect(reused.id, legacyId);
    expect(await objectStore.listObjects(definition.objectType.id), hasLength(1));
    expect(reused.values[definition.fileProperty.id], managed.path);
  });

  test('external Image path remains absolute', () async {
    final root = await Directory.systemTemp.createTemp('image_path_profile_');
    final external = await Directory.systemTemp.createTemp('image_path_external_');
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => external.delete(recursive: true));
    final source = File('${external.path}/outside.png');
    await source.writeAsBytes(const <int>[7, 8, 9]);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
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

    final image = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: source.path,
    );

    expect(image.values[definition.fileProperty.id], source.path);
  });
}
