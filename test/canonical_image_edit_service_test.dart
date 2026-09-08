import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:bookmark_app/services/image_edit_service.dart';
import 'package:bookmark_app/services/image_managed_file_deletion_policy.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'support/legacy_photo_fixture.dart';

void main() {
  AppObject expectedObject({int id = 7}) {
    final now = DateTime(2026, 9, 6);
    return AppObject(
      id: id,
      objectTypeId: 3,
      title: 'Image',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('exclusive canonical Image edit refreshes persisted geometry', () async {
    final directory = await Directory.systemTemp.createTemp('canonical_edit_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.png');
    await file.writeAsBytes(image.encodePng(image.Image(width: 4, height: 2)));

    int? updatedWidth;
    int? updatedHeight;
    final expected = expectedObject();
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async {
        expect(workspaceId, 11);
        expect(objectId, 7);
        return 'stored/image.png';
      },
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async {
        expect(objectId, 7);
        expect(filePath, 'stored/image.png');
        return file.path;
      },
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async {
        expect(workspaceId, 11);
        expect(objectId, 7);
        updatedWidth = pixelWidth;
        updatedHeight = pixelHeight;
        return expected;
      },
    );

    final result = await service.edit(
      workspaceId: 11,
      objectId: 7,
      quarterTurns: 1,
    );

    final decoded = image.decodeImage(await file.readAsBytes());
    expect(result, same(expected));
    expect(decoded, isNotNull);
    expect(decoded!.width, 2);
    expect(decoded.height, 4);
    expect(updatedWidth, 2);
    expect(updatedHeight, 4);
  });

  test('missing canonical Image file fails before ownership audit', () async {
    var ownershipChecked = false;
    var updated = false;
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async => null,
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async {
        ownershipChecked = true;
        return filePath;
      },
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async {
        updated = true;
        return expectedObject(id: objectId);
      },
    );

    await expectLater(
      service.edit(workspaceId: 1, objectId: 2, quarterTurns: 1),
      throwsA(isA<CanonicalImageEditTargetException>()),
    );
    expect(ownershipChecked, isFalse);
    expect(updated, isFalse);
  });

  test('shared or ambiguous managed Image fails closed before mutation', () async {
    var updated = false;
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async =>
          'shared.png',
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
          null,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async {
        updated = true;
        return expectedObject(id: objectId);
      },
    );

    await expectLater(
      service.edit(workspaceId: 1, objectId: 2, quarterTurns: 1),
      throwsA(isA<CanonicalImageEditOwnershipException>()),
    );
    expect(updated, isFalse);
  });

  test('geometry persistence failure rolls back edited bytes and new backup', () async {
    final directory = await Directory.systemTemp.createTemp('canonical_edit_rollback_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.png');
    final original = image.encodePng(image.Image(width: 5, height: 3));
    await file.writeAsBytes(original);

    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async =>
          'stored/image.png',
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
          file.path,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async => throw StateError('persist failed'),
    );

    await expectLater(
      service.edit(workspaceId: 1, objectId: 2, quarterTurns: 1),
      throwsStateError,
    );

    expect(await file.readAsBytes(), original);
    expect(await File('${file.path}.bookmark_original').exists(), isFalse);
  });

  test('canonical restore uses the same ownership guard and refreshes geometry',
      () async {
    final directory = await Directory.systemTemp.createTemp('canonical_restore_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.png');
    await file.writeAsBytes(image.encodePng(image.Image(width: 6, height: 4)));
    const rawEdit = ImageEditService();
    await rawEdit.apply(path: file.path, quarterTurns: 1);
    final edited = image.decodeImage(await file.readAsBytes());
    expect(edited, isNotNull);
    expect(edited!.width, 4);
    expect(edited.height, 6);

    int? updatedWidth;
    int? updatedHeight;
    final expected = expectedObject(id: 9);
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async =>
          'stored/image.png',
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
          file.path,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async {
        updatedWidth = pixelWidth;
        updatedHeight = pixelHeight;
        return expected;
      },
    );

    final result = await service.restoreOriginal(workspaceId: 1, objectId: 9);

    final restored = image.decodeImage(await file.readAsBytes());
    expect(result, same(expected));
    expect(restored, isNotNull);
    expect(restored!.width, 6);
    expect(restored.height, 4);
    expect(updatedWidth, 6);
    expect(updatedHeight, 4);
  });

  test('factory uses canonical File identity and blocks later legacy sharing',
      () async {
    final root = await Directory.systemTemp.createTemp('canonical_edit_factory_');
    addTearDown(() => root.delete(recursive: true));
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
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final photoStorage = PhotoStorageService(
      photoDirectoryPath: photoDirectory.path,
    );
    final ownershipPolicy = ImageManagedFileDeletionPolicy(
      database: database,
      objectStore: objectStore,
      photoStorage: photoStorage,
    );
    final service = CanonicalImageEditService.fromServices(
      ownershipPolicy: ownershipPolicy,
      images: images,
    );
    final file = File('${photoDirectory.path}/factory.png');
    await file.writeAsBytes(image.encodePng(image.Image(width: 8, height: 4)));
    final storedPath = database.pathResolver.toStoredPath(file.path);
    final imageObject = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: storedPath,
      pixelWidth: 8,
      pixelHeight: 4,
    );

    final editedObject = await service.edit(
      workspaceId: workspaceId,
      objectId: imageObject.id,
      quarterTurns: 1,
    );
    final definition = await images.ensureDefinition(workspaceId);
    expect(editedObject.values[definition.pixelWidthProperty.id], 4);
    expect(editedObject.values[definition.pixelHeightProperty.id], 8);
    final bytesBeforeBlockedEdit = await file.readAsBytes();

    await database.addPhoto(path: file.path);

    await expectLater(
      service.edit(
        workspaceId: workspaceId,
        objectId: imageObject.id,
        quarterTurns: 1,
      ),
      throwsA(isA<CanonicalImageEditOwnershipException>()),
    );
    expect(await file.readAsBytes(), bytesBeforeBlockedEdit);
  });
}
