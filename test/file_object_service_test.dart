import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical File stores a portable managed identity and metadata', () async {
    final root = await Directory.systemTemp.createTemp('file_object_service_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/files/Report.PDF');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes(const <int>[1, 2, 3, 4, 5]);

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
    final service = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    final importedAt = DateTime.utc(2026, 9, 7, 1, 2, 3);

    final object = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      originalFilename: 'Report.PDF',
      contentType: 'Application/PDF; charset=binary',
      sizeBytes: 5,
      importedAt: importedAt,
    );

    expect(definition.objectType.kind.name, 'system');
    expect(object.title, 'Report.PDF');
    expect(object.values[definition.fileProperty.id], 'files/Report.PDF');
    expect(
      object.values[definition.originalFilenameProperty.id],
      'Report.PDF',
    );
    expect(object.values[definition.contentTypeProperty.id], 'application/pdf');
    expect(object.values[definition.extensionProperty.id], 'pdf');
    expect(object.values[definition.sizeBytesProperty.id], 5);
    expect(
      object.values[definition.importedAtProperty.id],
      importedAt.toIso8601String(),
    );
  });

  test('reimport by equivalent stored path reuses File and preserves metadata',
      () async {
    final root = await Directory.systemTemp.createTemp('file_object_reuse_');
    addTearDown(() => root.delete(recursive: true));
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

    final first = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '${root.path}/files/report.pdf',
      originalFilename: 'report.pdf',
      contentType: 'application/pdf',
      sizeBytes: 10,
      importedAt: DateTime.utc(2026, 9, 7),
    );
    final second = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'files/report.pdf',
      originalFilename: 'renamed.pdf',
      contentType: 'application/octet-stream',
      sizeBytes: 99,
      importedAt: DateTime.utc(2026, 9, 8),
    );

    expect(second.id, first.id);
    expect(
      second.values[definition.originalFilenameProperty.id],
      'report.pdf',
    );
    expect(second.values[definition.contentTypeProperty.id], 'application/pdf');
    expect(second.values[definition.sizeBytesProperty.id], 10);
    expect(
      second.values[definition.importedAtProperty.id],
      DateTime.utc(2026, 9, 7).toIso8601String(),
    );
  });

  test('reimport fills a missing File import timestamp', () async {
    final root = await Directory.systemTemp.createTemp('file_object_enrich_');
    addTearDown(() => root.delete(recursive: true));
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
    final service = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    final objectId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'legacy.pdf',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: definition.fileProperty,
      value: 'files/legacy.pdf',
    );
    final importedAt = DateTime.utc(2026, 9, 7, 4, 5, 6);

    final enriched = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '${root.path}/files/legacy.pdf',
      importedAt: importedAt,
    );

    expect(enriched.id, objectId);
    expect(
      enriched.values[definition.importedAtProperty.id],
      importedAt.toIso8601String(),
    );
  });

  test('File and Image remain distinct primitive ObjectTypes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final defaults = ObjectTypeDefaultsStore(genericStore);

    final fileDefinition = await FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    ).ensureDefinition(workspaceId);
    final imageDefinition = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    ).ensureDefinition(workspaceId);

    expect(fileDefinition.objectType.id, isNot(imageDefinition.objectType.id));
    expect(
      await systemObjects.systemKeyForObjectType(fileDefinition.objectType.id),
      FileObjectService.systemKey,
    );
    expect(
      await systemObjects.systemKeyForObjectType(imageDefinition.objectType.id),
      ImageObjectService.systemKey,
    );
  });

  test('invalid managed File identity is rejected', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: ObjectStore(genericStore),
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    await expectLater(
      service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '   ',
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/file.bin',
        sizeBytes: -1,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
