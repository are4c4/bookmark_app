import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('absolute legacy Photo reuses relative canonical Image in profile root',
      () async {
    final root = await Directory.systemTemp.createTemp('photo_path_identity_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/photos/shared.jpg');
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
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final imageService = ImageObjectService(
      systemObjects: systemStore,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await imageService.ensureDefinition(workspaceId);
    final native = await imageService.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'photos/shared.jpg',
      title: 'Native image',
      originalFilename: 'shared.jpg',
    );
    await database.customStatement(
      'INSERT INTO photos(path, title) VALUES (?, ?)',
      <Object>[managed.path, 'Legacy absolute'],
    );
    final photoId = (await database.customSelect(
      'SELECT id FROM photos WHERE path = ?',
      variables: [Variable<String>(managed.path)],
    ).getSingle())
        .read<int>('id');
    final bridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
      tagBridge: TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemStore,
      ),
    );

    await bridge.syncAll(workspaceId);
    await bridge.syncAll(workspaceId);

    final imageType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
    ))!;
    final legacyIdProperty = imageType.properties
        .singleWhere((property) => property.name == 'Legacy Photo ID');
    final images = await objectStore.listObjects(imageType.id);
    expect(images, hasLength(1));
    expect(images.single.id, native.id);
    expect(images.single.title, 'Native image');
    expect(images.single.values[definition.fileProperty.id], 'photos/shared.jpg');
    expect(images.single.values[legacyIdProperty.id], isNull);

    final mapping = await database.customSelect(
      'SELECT object_id FROM photo_object_links '
      'WHERE workspace_id = ? AND photo_id = ?',
      variables: [Variable<int>(workspaceId), Variable<int>(photoId)],
    ).getSingle();
    expect(mapping.read<int>('object_id'), native.id);
  });

  test('new Photo promotion stores profile-relative File identity', () async {
    final root = await Directory.systemTemp.createTemp('photo_path_relative_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/photos/legacy.jpg');
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
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final bridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
      tagBridge: TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemStore,
      ),
    );
    await database.customStatement(
      'INSERT INTO photos(path, title) VALUES (?, ?)',
      <Object>[managed.path, 'Legacy absolute'],
    );

    await bridge.syncAll(workspaceId);

    final imageType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
    ))!;
    final fileProperty =
        imageType.properties.singleWhere((property) => property.name == 'File');
    final promoted = (await objectStore.listObjects(imageType.id)).single;
    expect(promoted.values[fileProperty.id], 'photos/legacy.jpg');
  });
}
