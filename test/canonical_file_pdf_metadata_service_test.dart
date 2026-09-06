import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/canonical_file_pdf_metadata_service.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:bookmark_app/services/pdf_metadata_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PDF content enables metadata capability on canonical File', () async {
    final root = await Directory.systemTemp.createTemp('file_pdf_metadata_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/files/disguised.bin');
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
    final files = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await files.ensureDefinition(workspaceId);
    final fileObject = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      originalFilename: 'disguised.bin',
      contentType: 'application/octet-stream',
    );

    String? metadataPath;
    final service = CanonicalFilePdfMetadataService(
      resources: FileManagedResourceResolver(
        objectStore,
        pathResolver: ProfilePathResolver(root.path),
      ),
      readMetadata: (path) async {
        metadataPath = path;
        return const PdfFileMetadata(
          title: 'Canonical PDF',
          authors: <String>['Ada', 'Grace'],
        );
      },
    );

    final metadata = await service.resolve(
      fileObjectTypeId: definition.objectType.id,
      fileObjectId: fileObject.id,
    );

    expect(metadata?.fileObjectId, fileObject.id);
    expect(metadata?.title, 'Canonical PDF');
    expect(metadata?.authors, <String>['Ada', 'Grace']);
    expect(metadataPath, managed.path);
  });

  test('non-PDF content overrides conflicting stored PDF MIME', () async {
    final root = await Directory.systemTemp.createTemp('file_not_pdf_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/files/not-really.pdf');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes(const <int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final files = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await files.ensureDefinition(workspaceId);
    final fileObject = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      contentType: 'application/pdf',
    );
    var reads = 0;
    final service = CanonicalFilePdfMetadataService(
      resources: FileManagedResourceResolver(
        objectStore,
        pathResolver: ProfilePathResolver(root.path),
      ),
      readMetadata: (path) async {
        reads++;
        return const PdfFileMetadata(title: 'should not run');
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

  test('missing canonical File has no PDF metadata capability', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final files = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await files.ensureDefinition(workspaceId);
    final fileObject = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/definitely/missing/paper.pdf',
      contentType: 'application/pdf',
    );
    var reads = 0;
    final service = CanonicalFilePdfMetadataService(
      resources: FileManagedResourceResolver(objectStore),
      readMetadata: (path) async {
        reads++;
        return const PdfFileMetadata(title: 'missing');
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
}
