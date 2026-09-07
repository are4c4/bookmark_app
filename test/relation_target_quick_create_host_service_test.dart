import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_target_quick_create_policy.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/relation_target_quick_create_host_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory vault;
  late Directory sources;
  late AppDatabase database;
  late int workspaceId;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late SystemObjectStore systemObjects;
  late ObjectTypeDefaultsStore defaults;
  late GenericDatabasePageServices services;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('relation_quick_create_vault_');
    sources =
        await Directory.systemTemp.createTemp('relation_quick_create_source_');
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: vault.path,
    );
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    defaults = ObjectTypeDefaultsStore(genericStore);
    services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
      photoStorage: PhotoStorageService(
        photoDirectoryPath: '${vault.path}/photos',
      ),
    );
  });

  tearDown(() async {
    await database.close();
    await vault.delete(recursive: true);
    await sources.delete(recursive: true);
  });

  RelationTargetQuickCreateHostService hostFor(String path) =>
      RelationTargetQuickCreateHostService(
        policy: services.relationQuickCreatePolicy,
        quickCreate: services.relationQuickCreate,
        imageImport: services.imageImport,
        fileImport: services.fileImport,
        pickFile: () async => path,
      );

  test('custom target keeps normal title-based quick-create', () async {
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Author',
    );
    final host = hostFor('unused');
    final mode = await host.modeFor(
      workspaceId: workspaceId,
      targetObjectTypeId: targetTypeId,
    );

    expect(mode, RelationTargetQuickCreateMode.genericObject);
    expect(host.requiresInput(mode), isTrue);
    final objectId = await host.create(
      workspaceId: workspaceId,
      targetObjectTypeId: targetTypeId,
      mode: mode,
      input: 'Ada Lovelace',
    );

    expect(objectId, isNotNull);
    final objects = await objectStore.listObjects(targetTypeId);
    expect(objects.single.id, objectId);
    expect(objects.single.title, 'Ada Lovelace');
  });

  test('File target rejects Image content before either primitive is created',
      () async {
    final imageDefinition = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    ).ensureDefinition(workspaceId);
    final fileDefinition = await FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    ).ensureDefinition(workspaceId);
    final source = File('${sources.path}/looks-like-file.bin');
    await source.writeAsBytes(
      const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3],
    );
    final host = hostFor(source.path);
    final mode = await host.modeFor(
      workspaceId: workspaceId,
      targetObjectTypeId: fileDefinition.objectType.id,
    );

    expect(mode, RelationTargetQuickCreateMode.managedFile);
    expect(host.requiresInput(mode), isFalse);
    await expectLater(
      host.create(
        workspaceId: workspaceId,
        targetObjectTypeId: fileDefinition.objectType.id,
        mode: mode,
      ),
      throwsStateError,
    );
    expect(
      await objectStore.listObjects(fileDefinition.objectType.id),
      isEmpty,
    );
    expect(
      await objectStore.listObjects(imageDefinition.objectType.id),
      isEmpty,
    );
  });

  test('File target imports classified File through Vault managed-copy',
      () async {
    final fileDefinition = await FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    ).ensureDefinition(workspaceId);
    final source = File('${sources.path}/paper.png');
    await source.writeAsBytes('%PDF-1.7\nbody'.codeUnits);
    final host = hostFor(source.path);
    final mode = await host.modeFor(
      workspaceId: workspaceId,
      targetObjectTypeId: fileDefinition.objectType.id,
    );

    final objectId = await host.create(
      workspaceId: workspaceId,
      targetObjectTypeId: fileDefinition.objectType.id,
      mode: mode,
    );

    expect(objectId, isNotNull);
    final objects = await objectStore.listObjects(fileDefinition.objectType.id);
    expect(objects.single.id, objectId);
    final storedPath =
        '${objects.single.values[fileDefinition.fileProperty.id] ?? ''}';
    expect(storedPath, startsWith('attachments/'));
    expect(await File('${vault.path}/$storedPath').exists(), isTrue);
  });

  test('Image target rejects non-Image content before File creation', () async {
    final imageDefinition = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    ).ensureDefinition(workspaceId);
    final fileDefinition = await FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    ).ensureDefinition(workspaceId);
    final source = File('${sources.path}/paper.pdf');
    await source.writeAsBytes('%PDF-1.7\nbody'.codeUnits);
    final host = hostFor(source.path);
    final mode = await host.modeFor(
      workspaceId: workspaceId,
      targetObjectTypeId: imageDefinition.objectType.id,
    );

    expect(mode, RelationTargetQuickCreateMode.managedImage);
    await expectLater(
      host.create(
        workspaceId: workspaceId,
        targetObjectTypeId: imageDefinition.objectType.id,
        mode: mode,
      ),
      throwsStateError,
    );
    expect(
      await objectStore.listObjects(imageDefinition.objectType.id),
      isEmpty,
    );
    expect(
      await objectStore.listObjects(fileDefinition.objectType.id),
      isEmpty,
    );
  });
}
