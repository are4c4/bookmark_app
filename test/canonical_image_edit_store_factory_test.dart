import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'support/legacy_photo_fixture.dart';

void main() {
  test('store factory preserves canonical ownership preflight', () async {
    final root =
        await Directory.systemTemp.createTemp('canonical_edit_store_factory_');
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
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final file = File('${photoDirectory.path}/factory.png');
    await file.writeAsBytes(
      image.encodePng(image.Image(width: 8, height: 4)),
    );
    final imageObject = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: database.pathResolver.toStoredPath(file.path),
      pixelWidth: 8,
      pixelHeight: 4,
    );

    final service = CanonicalImageEditService.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
      photoStorage: PhotoStorageService(
        photoDirectoryPath: photoDirectory.path,
      ),
    );

    expect(
      await service.canEdit(
        workspaceId: workspaceId,
        objectId: imageObject.id,
      ),
      isTrue,
    );

    // A later legacy Photo sharing the same physical file must make the exact
    // same composed service fail closed before any mutation.
    await database.addPhoto(path: file.path);

    expect(
      await service.canEdit(
        workspaceId: workspaceId,
        objectId: imageObject.id,
      ),
      isFalse,
    );
  });
}
