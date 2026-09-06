import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/photo_managed_file_deletion_policy.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy-only Photo file remains deletable before canonical Image mirroring',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final photoId = await database.addPhoto(path: 'photos/legacy-only.jpg');

    final policy = PhotoManagedFileDeletionPolicy(database);
    expect(
      await policy.shouldPreserve(
        legacyPhotoId: photoId,
        filePath: 'photos/legacy-only.jpg',
      ),
      isFalse,
    );
  });

  test('legacy-owned mirror alone does not claim independent file ownership',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final bridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      tagBridge: TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
      ),
    );
    final photoId = await database.addPhoto(path: 'photos/mirrored.jpg');

    await bridge.syncAll(workspaceId);

    final policy = PhotoManagedFileDeletionPolicy(database);
    expect(
      await policy.shouldPreserve(
        legacyPhotoId: photoId,
        filePath: 'photos/mirrored.jpg',
      ),
      isFalse,
    );
  });

  test('native Image reused by legacy Photo preserves the shared managed file',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
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
    final nativeImage = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'photos/shared.jpg',
      title: 'Native image',
    );
    final photoId = await database.addPhoto(path: 'photos/shared.jpg');
    final bridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      tagBridge: TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
      ),
    );

    await bridge.syncAll(workspaceId);

    final link = await database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE photo_id = $photoId',
    ).getSingle();
    expect(link.read<int>('object_id'), nativeImage.id);

    final policy = PhotoManagedFileDeletionPolicy(database);
    expect(
      await policy.shouldPreserve(
        legacyPhotoId: photoId,
        filePath: 'photos/shared.jpg',
      ),
      isTrue,
    );
  });

  test('another workspace Image sharing the resolved file also preserves it',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final firstWorkspaceId = await workspaceStore.initialize();
    final secondWorkspaceId = await workspaceStore.createWorkspace('Second');
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
    await images.findOrCreateManaged(
      workspaceId: secondWorkspaceId,
      filePath: 'photos/cross-workspace.jpg',
      title: 'Second workspace native image',
    );
    final photoId = await database.addPhoto(path: 'photos/cross-workspace.jpg');
    final bridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      tagBridge: TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
      ),
    );

    await bridge.syncAll(firstWorkspaceId);

    final policy = PhotoManagedFileDeletionPolicy(database);
    expect(
      await policy.shouldPreserve(
        legacyPhotoId: photoId,
        filePath: 'photos/cross-workspace.jpg',
      ),
      isTrue,
    );
  });
}