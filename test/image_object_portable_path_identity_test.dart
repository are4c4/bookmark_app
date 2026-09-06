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
  test('managed Image stores profile-local absolute path as relative identity',
      () async {
    final fixture = await _ImagePathFixture.create();
    addTearDown(fixture.dispose);
    final source = await fixture.createManagedImage('native.png');
    final definition = await fixture.images.ensureDefinition(fixture.workspaceId);

    final image = await fixture.images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: source.path,
      title: 'Native',
    );

    expect(image.values[definition.fileProperty.id], 'photos/native.png');
  });

  test('relative reimport reuses and upgrades older absolute Image path',
      () async {
    final fixture = await _ImagePathFixture.create();
    addTearDown(fixture.dispose);
    final source = await fixture.createManagedImage('legacy-absolute.png');
    final definition = await fixture.images.ensureDefinition(fixture.workspaceId);
    final original = await fixture.images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: source.path,
      title: 'Existing image',
    );

    // Simulate an Image persisted before managed path identity became portable.
    await fixture.objectStore.setPropertyValue(
      objectId: original.id,
      property: definition.fileProperty,
      value: source.path,
    );

    final reused = await fixture.images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: 'photos/legacy-absolute.png',
      title: 'Retry title',
    );

    expect(reused.id, original.id);
    expect(reused.title, 'Existing image');
    expect(
      reused.values[definition.fileProperty.id],
      'photos/legacy-absolute.png',
    );
    expect(
      await fixture.objectStore.listObjects(definition.objectType.id),
      hasLength(1),
    );
  });

  test('external absolute Image path remains external', () async {
    final fixture = await _ImagePathFixture.create();
    addTearDown(fixture.dispose);
    final external = await Directory.systemTemp.createTemp('image_external_');
    addTearDown(() => external.delete(recursive: true));
    final source = File('${external.path}/outside.png');
    await source.writeAsBytes(const <int>[1, 2, 3]);
    final definition = await fixture.images.ensureDefinition(fixture.workspaceId);

    final image = await fixture.images.findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: source.path,
      title: 'External',
    );

    expect(image.values[definition.fileProperty.id], source.path);
  });
}

class _ImagePathFixture {
  const _ImagePathFixture({
    required this.root,
    required this.database,
    required this.workspaceId,
    required this.objectStore,
    required this.images,
  });

  final Directory root;
  final AppDatabase database;
  final int workspaceId;
  final ObjectStore objectStore;
  final ImageObjectService images;

  static Future<_ImagePathFixture> create() async {
    final root = await Directory.systemTemp.createTemp('image_path_identity_');
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
    return _ImagePathFixture(
      root: root,
      database: database,
      workspaceId: workspaceId,
      objectStore: objectStore,
      images: images,
    );
  }

  Future<File> createManagedImage(String name) async {
    final file = File('${root.path}/photos/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[1, 2, 3]);
    return file;
  }

  Future<void> dispose() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
