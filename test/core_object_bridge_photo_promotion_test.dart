import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Photo promotion reuses an existing managed Image with the exact File',
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
    final nativeImage = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'photos/shared.jpg',
      title: 'Native before promotion',
      originalFilename: 'shared.jpg',
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
    final imageObjects = await objectStore.listObjects(imageType.id);
    expect(imageObjects, hasLength(1));
    expect(imageObjects.single.id, nativeImage.id);
    expect(imageObjects.single.title, 'Legacy shared');

    final legacyIdProperty =
        imageType.properties.singleWhere((property) => property.name == 'Legacy Photo ID');
    final fileProperty =
        imageType.properties.singleWhere((property) => property.name == 'File');
    final noteProperty =
        imageType.properties.singleWhere((property) => property.name == 'Note');
    final filenameProperty = imageType.properties
        .singleWhere((property) => property.name == 'Original filename');
    expect(imageObjects.single.values[legacyIdProperty.id], photoId);
    expect(imageObjects.single.values[fileProperty.id], 'photos/shared.jpg');
    expect(imageObjects.single.values[noteProperty.id], 'Legacy note');
    expect(imageObjects.single.values[filenameProperty.id], 'shared.jpg');

    final link = await database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
      variables: [
        driftVariable(workspaceId),
        driftVariable(photoId),
      ],
    ).getSingle();
    expect(link.read<int>('object_id'), nativeImage.id);
  });
}

Variable<T> driftVariable<T>(T value) => Variable<T>(value);
