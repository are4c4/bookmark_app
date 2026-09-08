import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/legacy_photo_image_deletion_service.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/legacy_photo_fixture.dart';

void main() {
  test('native Image reused by legacy Photo mapping deletes both identities', () async {
    final fixture = await _MappingFixture.create();
    addTearDown(fixture.dispose);
    final managedFile = await fixture.createManagedFile('native-mapped.png');
    final nativeImage = await fixture.images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: fixture.database.pathResolver.toStoredPath(managedFile.path),
      title: 'Native mapped image',
    );
    final photoId = await fixture.database.addPhoto(path: managedFile.path);

    await fixture.syncLegacyPhotoMirrors();

    final imageType = (await fixture.systemObjects.getSystemObjectType(
      workspaceId: fixture.workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    final images = await fixture.objectStore.listObjects(imageType.id);
    expect(images, hasLength(1));
    expect(images.single.id, nativeImage.id);
    final legacyPhotoId = imageType.properties.singleWhere(
      (property) => property.name == 'Legacy Photo ID',
    );
    expect(images.single.values[legacyPhotoId.id], isNull);
    final mapping = await fixture.database
        .customSelect(
          'SELECT object_id FROM photo_object_links '
          'WHERE workspace_id = ${fixture.workspaceId} AND photo_id = $photoId',
        )
        .getSingle();
    expect(mapping.read<int>('object_id'), nativeImage.id);

    await fixture.services.relationMutations.deleteObject(
      workspaceId: fixture.workspaceId,
      objectTypeId: imageType.id,
      objectId: nativeImage.id,
    );

    expect(await managedFile.exists(), isFalse);
    expect(await fixture.objectStore.listObjects(imageType.id), isEmpty);
    expect(
      await fixture.database
          .customSelect('SELECT id FROM photos WHERE id = $photoId')
          .get(),
      isEmpty,
    );
  });

  test('mismatched legacy Photo id fails closed without deleting either side', () async {
    final fixture = await _MappingFixture.create();
    addTearDown(fixture.dispose);
    final managedFile = await fixture.createManagedFile('mismatch.png');
    final photoId = await fixture.database.addPhoto(path: managedFile.path);
    final otherPhotoId = await fixture.database.addPhoto(
      path: (await fixture.createManagedFile('other.png')).path,
    );

    await fixture.syncLegacyPhotoMirrors();

    final imageType = (await fixture.systemObjects.getSystemObjectType(
      workspaceId: fixture.workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    final legacyPhotoId = imageType.properties.singleWhere(
      (property) => property.name == 'Legacy Photo ID',
    );
    final images = await fixture.objectStore.listObjects(imageType.id);
    final image = images.singleWhere(
      (candidate) => candidate.values[legacyPhotoId.id] == photoId,
    );
    await fixture.objectStore.setPropertyValue(
      objectId: image.id,
      property: legacyPhotoId,
      value: otherPhotoId,
    );

    await expectLater(
      fixture.services.relationMutations.deleteObject(
        workspaceId: fixture.workspaceId,
        objectTypeId: imageType.id,
        objectId: image.id,
      ),
      throwsA(isA<LegacyPhotoImageDeletionSafetyException>()),
    );

    expect(await managedFile.exists(), isTrue);
    expect(
      (await fixture.objectStore.listObjects(imageType.id))
          .map((candidate) => candidate.id),
      contains(image.id),
    );
    expect(
      await fixture.database
          .customSelect('SELECT id FROM photos WHERE id = $photoId')
          .get(),
      hasLength(1),
    );
    expect(
      await fixture.database
          .customSelect(
            'SELECT photo_id FROM photo_object_links '
            'WHERE workspace_id = ${fixture.workspaceId} AND object_id = ${image.id}',
          )
          .get(),
      hasLength(1),
    );
  });

  test(
    'mapped Photo file mismatch fails closed for a reused native Image',
    () async {
      final fixture = await _MappingFixture.create();
      addTearDown(fixture.dispose);
      final managedFile = await fixture.createManagedFile('native-path.png');
      final nativeImage = await fixture.images.findOrCreateManaged(
        workspaceId: fixture.workspaceId,
        filePath: fixture.database.pathResolver.toStoredPath(managedFile.path),
        title: 'Native path image',
      );
      final photoId = await fixture.database.addPhoto(path: managedFile.path);

      await fixture.syncLegacyPhotoMirrors();

      final differentFile = await fixture.createManagedFile('different.png');
      await fixture.database.customStatement(
        'UPDATE photos SET path = ? WHERE id = ?',
        <Object>[
          fixture.database.pathResolver.toStoredPath(differentFile.path),
          photoId,
        ],
      );
      final imageType = (await fixture.systemObjects.getSystemObjectType(
        workspaceId: fixture.workspaceId,
        systemKey: CoreObjectBridge.photoSystemKey,
      ))!;

      await expectLater(
        fixture.services.relationMutations.deleteObject(
          workspaceId: fixture.workspaceId,
          objectTypeId: imageType.id,
          objectId: nativeImage.id,
        ),
        throwsA(isA<LegacyPhotoImageDeletionSafetyException>()),
      );

      expect(await managedFile.exists(), isTrue);
      expect(await differentFile.exists(), isTrue);
      expect(
        (await fixture.objectStore.listObjects(imageType.id))
            .map((candidate) => candidate.id),
        contains(nativeImage.id),
      );
      expect(
        await fixture.database
            .customSelect('SELECT id FROM photos WHERE id = $photoId')
            .get(),
        hasLength(1),
      );
    },
  );
}

class _MappingFixture {
  _MappingFixture({
    required this.root,
    required this.photoDirectory,
    required this.database,
    required this.workspaceId,
    required this.objectStore,
    required this.systemObjects,
    required this.images,
    required this.services,
  });

  final Directory root;
  final Directory photoDirectory;
  final AppDatabase database;
  final int workspaceId;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;
  final ImageObjectService images;
  final GenericDatabasePageServices services;

  static Future<_MappingFixture> create() async {
    final root = await Directory.systemTemp.createTemp('image_delete_mapping_');
    final photoDirectory = Directory('${root.path}/photos');
    await photoDirectory.create(recursive: true);
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
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
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
      photoStorage: PhotoStorageService(
        photoDirectoryPath: photoDirectory.path,
      ),
    );
    return _MappingFixture(
      root: root,
      photoDirectory: photoDirectory,
      database: database,
      workspaceId: workspaceId,
      objectStore: objectStore,
      systemObjects: systemObjects,
      images: images,
      services: services,
    );
  }

  Future<void> syncLegacyPhotoMirrors() async {
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
