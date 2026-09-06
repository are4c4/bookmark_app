import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('File deletion preserves profile-local bytes without ownership grant',
      () async {
    final root = await Directory.systemTemp.createTemp('file_delete_profile_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/attachments/report.pdf');
    await source.parent.create(recursive: true);
    await source.writeAsBytes('%PDF-1.7\n'.codeUnits);

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
    final files = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await files.ensureDefinition(workspaceId);
    final object = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: source.path,
      title: 'Report',
      originalFilename: 'report.pdf',
      contentType: 'application/pdf',
    );
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    await services.relationMutations.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: definition.objectType.id,
      objectId: object.id,
    );

    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
    expect(await source.exists(), isTrue);
  });

  test('File deletion never treats an external reference as owned bytes',
      () async {
    final root = await Directory.systemTemp.createTemp('file_delete_vault_');
    final external =
        await Directory.systemTemp.createTemp('file_delete_external_');
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => external.delete(recursive: true));
    final source = File('${external.path}/external.bin');
    await source.writeAsBytes(const <int>[1, 2, 3, 4]);

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
    final files = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await files.ensureDefinition(workspaceId);
    final object = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: source.path,
      title: 'External',
      originalFilename: 'external.bin',
      contentType: 'application/octet-stream',
    );
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    await services.relationMutations.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: definition.objectType.id,
      objectId: object.id,
    );

    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
    expect(await source.exists(), isTrue);
  });
}
