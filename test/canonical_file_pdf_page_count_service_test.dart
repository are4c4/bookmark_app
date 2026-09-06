import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/canonical_file_pdf_page_count_service.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PDF content exposes positive page count on canonical File', () async {
    final root = await Directory.systemTemp.createTemp('file_pdf_pages_');
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

    String? readPath;
    final service = CanonicalFilePdfPageCountService(
      resources: FileManagedResourceResolver(
        objectStore,
        pathResolver: ProfilePathResolver(root.path),
      ),
      readPageCount: (path) async {
        readPath = path;
        return 12;
      },
    );

    final result = await service.resolve(
      fileObjectTypeId: definition.objectType.id,
      fileObjectId: fileObject.id,
    );

    expect(result?.fileObjectId, fileObject.id);
    expect(result?.pageCount, 12);
    expect(readPath, managed.path);
  });

  test('non-PDF content never invokes page-count reader', () async {
    final root = await Directory.systemTemp.createTemp('file_non_pdf_pages_');
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
    final service = CanonicalFilePdfPageCountService(
      resources: FileManagedResourceResolver(
        objectStore,
        pathResolver: ProfilePathResolver(root.path),
      ),
      readPageCount: (path) async {
        reads++;
        return 99;
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

  test('missing File and invalid counts fail closed', () async {
    final root = await Directory.systemTemp.createTemp('file_pdf_pages_invalid_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/files/paper.pdf');
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
      contentType: 'application/pdf',
    );
    final resolver = FileManagedResourceResolver(
      objectStore,
      pathResolver: ProfilePathResolver(root.path),
    );
    final zeroService = CanonicalFilePdfPageCountService(
      resources: resolver,
      readPageCount: (path) async => 0,
    );

    expect(
      await zeroService.resolve(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      isNull,
    );

    await managed.delete();
    var reads = 0;
    final missingService = CanonicalFilePdfPageCountService(
      resources: resolver,
      readPageCount: (path) async {
        reads++;
        return 2;
      },
    );
    expect(
      await missingService.resolve(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      isNull,
    );
    expect(reads, 0);
  });
}
