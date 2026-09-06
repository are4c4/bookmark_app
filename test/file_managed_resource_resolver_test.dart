import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical File resolves through the shared portable file capability',
      () async {
    final root = await Directory.systemTemp.createTemp('file_resource_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/files/report.pdf');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes(const <int>[1, 2, 3, 4, 5, 6]);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    final fileObject = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      originalFilename: 'report.pdf',
      contentType: 'application/pdf',
      sizeBytes: 6,
    );

    final resource = await FileManagedResourceResolver(
      objectStore,
      pathResolver: ProfilePathResolver(root.path),
    ).resolveManaged(
      fileObjectTypeId: definition.objectType.id,
      fileObjectId: fileObject.id,
    );

    expect(resource, isNotNull);
    expect(resource?.fileObjectId, fileObject.id);
    expect(resource?.filePath, managed.path);
    expect(resource?.originalFilename, 'report.pdf');
    expect(resource?.contentType, 'application/pdf');
    expect(resource?.extension, 'pdf');
    expect(resource?.persistedSizeBytes, 6);
    expect(resource?.actualSizeBytes, 6);
    expect(resource?.modifiedAt, isA<DateTime>());
  });

  test('missing managed File fails closed without mutating metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    final fileObject = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/definitely/missing/report.pdf',
      sizeBytes: 100,
    );

    expect(
      await FileManagedResourceResolver(objectStore).resolveManaged(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      isNull,
    );
    final reloaded = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == fileObject.id);
    expect(reloaded.values[definition.sizeBytesProperty.id], 100);
  });
}
