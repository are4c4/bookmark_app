import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/canonical_file_pdf_text_service.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PDF content exposes extracted text on canonical File', () async {
    final root = await Directory.systemTemp.createTemp('file_pdf_text_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/attachments/disguised.bin');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes('%PDF-1.7\nbody'.codeUnits);

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
    final fileObject = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      contentType: 'application/octet-stream',
    );

    String? readPath;
    final service = CanonicalFilePdfTextService(
      resources: CanonicalFileManagedResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
        pathResolver: database.pathResolver,
      ),
      readText: (path) async {
        readPath = path;
        return '  searchable PDF text  ';
      },
    );

    final text = await service.resolve(
      fileObjectTypeId: definition.objectType.id,
      fileObjectId: fileObject.id,
    );
    expect(text?.fileObjectId, fileObject.id);
    expect(text?.text, 'searchable PDF text');
    expect(readPath, managed.path);
  });

  test('non-PDF content never invokes PDF text reader', () async {
    final root = await Directory.systemTemp.createTemp('file_not_pdf_text_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/attachments/not-really.pdf');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes(const <int>[
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    ]);

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
    final fileObject = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      contentType: 'application/pdf',
    );
    var reads = 0;
    final service = CanonicalFilePdfTextService(
      resources: CanonicalFileManagedResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
        pathResolver: database.pathResolver,
      ),
      readText: (_) async {
        reads++;
        return 'wrong';
      },
    );

    expect(
      await service.resolve(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      isNull,
    );
    expect(reads, 0);
  });

  test('blank extracted text is treated as unavailable', () async {
    final root = await Directory.systemTemp.createTemp('file_blank_pdf_text_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/attachments/paper.pdf');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes('%PDF-1.7\nbody'.codeUnits);

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
    final fileObject = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      contentType: 'application/pdf',
    );
    final service = CanonicalFilePdfTextService(
      resources: CanonicalFileManagedResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
        pathResolver: database.pathResolver,
      ),
      readText: (_) async => '   ',
    );

    expect(
      await service.resolve(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      isNull,
    );
  });
}
