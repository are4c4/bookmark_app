import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy-only Photo deletion still removes its managed file', () async {
    final directory =
        await Directory.systemTemp.createTemp('legacy_photo_delete_');
    addTearDown(() => directory.delete(recursive: true));
    final photos = Directory('${directory.path}/photos');
    await photos.create();
    final managedFile = File('${photos.path}/legacy-only.jpg');
    await managedFile.writeAsBytes(const <int>[1, 2, 3]);

    final fixture = await _repositoryFixture(directory.path);
    addTearDown(fixture.database.close);
    final photoId = await fixture.database.addPhoto(
      path: 'photos/legacy-only.jpg',
    );
    final photo = (await fixture.repository.watchPhotos().first).singleWhere(
      (candidate) => candidate.id == photoId,
    );

    await fixture.repository.deletePhoto(photo);

    expect(await managedFile.exists(), isFalse);
    final rows = await fixture.database.customSelect(
      'SELECT id FROM photos WHERE id = $photoId',
    ).get();
    expect(rows, isEmpty);
  });

  test('Photo deletion preserves file reused by a native canonical Image',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('shared_image_delete_');
    addTearDown(() => directory.delete(recursive: true));
    final photos = Directory('${directory.path}/photos');
    await photos.create();
    final managedFile = File('${photos.path}/shared.jpg');
    await managedFile.writeAsBytes(const <int>[4, 5, 6]);

    final fixture = await _repositoryFixture(directory.path);
    addTearDown(fixture.database.close);
    final genericStore = GenericDatabaseStore(fixture.database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: fixture.database,
      objectStore: objectStore,
    );
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final nativeImage = await images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: 'photos/shared.jpg',
      title: 'Native owner',
    );
    final photoId = await fixture.database.addPhoto(path: 'photos/shared.jpg');
    final bridge = CoreObjectBridge(
      database: fixture.database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      tagBridge: TagObjectBridge(
        database: fixture.database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
      ),
    );
    await bridge.syncAll(fixture.workspaceId);

    final link = await fixture.database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE photo_id = $photoId',
    ).getSingle();
    expect(link.read<int>('object_id'), nativeImage.id);
    final photo = (await fixture.repository.watchPhotos().first).singleWhere(
      (candidate) => candidate.id == photoId,
    );

    await fixture.repository.deletePhoto(photo);

    expect(await managedFile.exists(), isTrue);
    expect(
      await fixture.database.customSelect(
        'SELECT id FROM photos WHERE id = $photoId',
      ).get(),
      isEmpty,
    );

    await bridge.syncAll(fixture.workspaceId);
    final imageType = (await systemObjects.getSystemObjectType(
      workspaceId: fixture.workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    final remainingImages = await objectStore.listObjects(imageType.id);
    expect(remainingImages.map((image) => image.id), contains(nativeImage.id));
  });

  test('legacy Photo row deletion preserves an external absolute file', () async {
    final directory =
        await Directory.systemTemp.createTemp('external_photo_delete_');
    addTearDown(() => directory.delete(recursive: true));
    final externalFile = File('${directory.path}/external.jpg');
    await externalFile.writeAsBytes(const <int>[7, 8, 9]);

    final fixture = await _repositoryFixture(directory.path);
    addTearDown(fixture.database.close);
    final photoId = await fixture.database.addPhoto(path: externalFile.path);
    final photo = (await fixture.repository.watchPhotos().first).singleWhere(
      (candidate) => candidate.id == photoId,
    );

    await fixture.repository.deletePhoto(photo);

    expect(await externalFile.exists(), isTrue);
    expect(
      await fixture.database.customSelect(
        'SELECT id FROM photos WHERE id = $photoId',
      ).get(),
      isEmpty,
    );
  });
}

Future<_RepositoryFixture> _repositoryFixture(String profileDirectoryPath) async {
  final photos = Directory('$profileDirectoryPath/photos');
  if (!await photos.exists()) {
    await photos.create(recursive: true);
  }
  final previousPhotoDirectory = PhotoStorageService.activePhotoDirectoryPath;
  PhotoStorageService.activePhotoDirectoryPath = photos.path;
  addTearDown(() {
    PhotoStorageService.activePhotoDirectoryPath = previousPhotoDirectory;
  });

  final database = AppDatabase.forTesting(
    NativeDatabase.memory(),
    profileDirectoryPath: profileDirectoryPath,
  );
  final workspaceStore = WorkspaceStore(database);
  final workspaceId = await workspaceStore.initialize();
  final lifecycleStore = BookmarkLifecycleStore(database);
  await lifecycleStore.initialize();
  final repository = BookmarkRepository(
    database,
    workspaceStore: workspaceStore,
    lifecycleStore: lifecycleStore,
    workspaceId: workspaceId,
    profileDirectoryPath: profileDirectoryPath,
  );
  return _RepositoryFixture(
    database: database,
    repository: repository,
    workspaceId: workspaceId,
  );
}

class _RepositoryFixture {
  const _RepositoryFixture({
    required this.database,
    required this.repository,
    required this.workspaceId,
  });

  final AppDatabase database;
  final BookmarkRepository repository;
  final int workspaceId;
}
