import 'dart:io';

import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic Image delete removes solely owned managed file and backup',
      () async {
    final fixture = await _DeleteFixture.create();
    addTearDown(fixture.dispose);
    final managedFile = await fixture.createManagedFile('sole.png');
    final backup = File('${managedFile.path}.bookmark_original');
    await backup.writeAsBytes(const <int>[9, 8, 7]);
    final image = await fixture.images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: managedFile.path,
      title: 'Sole image',
    );
    final imageType = await fixture.images.ensureDefinition(fixture.workspaceId);

    await fixture.services.relationMutations.deleteObject(
      workspaceId: fixture.workspaceId,
      objectTypeId: imageType.objectType.id,
      objectId: image.id,
    );

    expect(await managedFile.exists(), isFalse);
    expect(await backup.exists(), isFalse);
    expect(
      await fixture.objectStore.listObjects(imageType.objectType.id),
      isEmpty,
    );
  });

  test('generic Image delete preserves file still referenced by legacy Photo',
      () async {
    final fixture = await _DeleteFixture.create();
    addTearDown(fixture.dispose);
    final managedFile = await fixture.createManagedFile('legacy-shared.png');
    final photoId = await fixture.database.addPhoto(path: managedFile.path);
    final image = await fixture.images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: managedFile.path,
      title: 'Canonical image',
    );
    final imageType = await fixture.images.ensureDefinition(fixture.workspaceId);

    await fixture.services.relationMutations.deleteObject(
      workspaceId: fixture.workspaceId,
      objectTypeId: imageType.objectType.id,
      objectId: image.id,
    );

    expect(await managedFile.exists(), isTrue);
    expect(
      await fixture.database.customSelect(
        'SELECT id FROM photos WHERE id = $photoId',
      ).get(),
      hasLength(1),
    );
    expect(
      await fixture.objectStore.listObjects(imageType.objectType.id),
      isEmpty,
    );
  });

  test('generic Image delete preserves file shared by another workspace Image',
      () async {
    final fixture = await _DeleteFixture.create();
    addTearDown(fixture.dispose);
    final secondWorkspaceId =
        await fixture.workspaceStore.createWorkspace('Second workspace');
    final managedFile = await fixture.createManagedFile('workspace-shared.png');
    final first = await fixture.images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: managedFile.path,
      title: 'First image',
    );
    final second = await fixture.images.findOrCreateManaged(
      workspaceId: secondWorkspaceId,
      filePath: managedFile.path,
      title: 'Second image',
    );
    final firstType = await fixture.images.ensureDefinition(fixture.workspaceId);
    final secondType = await fixture.images.ensureDefinition(secondWorkspaceId);

    await fixture.services.relationMutations.deleteObject(
      workspaceId: fixture.workspaceId,
      objectTypeId: firstType.objectType.id,
      objectId: first.id,
    );

    expect(await managedFile.exists(), isTrue);
    expect(
      (await fixture.objectStore.listObjects(secondType.objectType.id))
          .map((object) => object.id),
      contains(second.id),
    );
  });

  test('generic Image delete never removes a file outside managed photo storage',
      () async {
    final fixture = await _DeleteFixture.create();
    addTearDown(fixture.dispose);
    final externalDirectory =
        await Directory.systemTemp.createTemp('image_delete_external_');
    addTearDown(() => externalDirectory.delete(recursive: true));
    final externalFile = File('${externalDirectory.path}/external.png');
    await externalFile.writeAsBytes(const <int>[4, 5, 6]);
    final image = await fixture.images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: externalFile.path,
      title: 'External reference',
    );
    final imageType = await fixture.images.ensureDefinition(fixture.workspaceId);

    await fixture.services.relationMutations.deleteObject(
      workspaceId: fixture.workspaceId,
      objectTypeId: imageType.objectType.id,
      objectId: image.id,
    );

    expect(await externalFile.exists(), isTrue);
    expect(
      await fixture.objectStore.listObjects(imageType.objectType.id),
      isEmpty,
    );
  });
}

class _DeleteFixture {
  _DeleteFixture({
    required this.root,
    required this.photoDirectory,
    required this.database,
    required this.workspaceStore,
    required this.workspaceId,
    required this.objectStore,
    required this.images,
    required this.services,
  });

  final Directory root;
  final Directory photoDirectory;
  final AppDatabase database;
  final WorkspaceStore workspaceStore;
  final int workspaceId;
  final ObjectStore objectStore;
  final ImageObjectService images;
  final GenericDatabasePageServices services;

  static Future<_DeleteFixture> create() async {
    final root = await Directory.systemTemp.createTemp('image_delete_profile_');
    final photoDirectory = Directory('${root.path}/photos');
    await photoDirectory.create(recursive: true);
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
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
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
      photoStorage: PhotoStorageService(
        photoDirectoryPath: photoDirectory.path,
      ),
    );
    return _DeleteFixture(
      root: root,
      photoDirectory: photoDirectory,
      database: database,
      workspaceStore: workspaceStore,
      workspaceId: workspaceId,
      objectStore: objectStore,
      images: images,
      services: services,
    );
  }

  Future<File> createManagedFile(String name) async {
    final file = File('${photoDirectory.path}/$name');
    await file.writeAsBytes(const <int>[1, 2, 3]);
    return file;
  }

  Future<void> dispose() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
