import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/canonical_file_pdf_preview_service.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PDF content exposes transient preview bytes on canonical File', () async {
    final fixture = await _Fixture.create(
      filename: 'disguised.bin',
      bytes: '%PDF-1.7\nbody'.codeUnits,
      contentType: 'application/octet-stream',
    );
    addTearDown(fixture.dispose);

    String? renderedPath;
    final service = CanonicalFilePdfPreviewService(
      resources: fixture.resources,
      renderPreview: (path) async {
        renderedPath = path;
        return <int>[1, 2, 3];
      },
    );

    final preview = await service.resolve(
      fileObjectTypeId: fixture.fileObjectTypeId,
      fileObjectId: fixture.fileObjectId,
    );

    expect(preview?.fileObjectId, fixture.fileObjectId);
    expect(preview?.pngBytes, <int>[1, 2, 3]);
    expect(renderedPath, fixture.filePath);
  });

  test('non-PDF content never invokes PDF preview renderer', () async {
    final fixture = await _Fixture.create(
      filename: 'not-really.pdf',
      bytes: const <int>[
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ],
      contentType: 'application/pdf',
    );
    addTearDown(fixture.dispose);
    var renders = 0;
    final service = CanonicalFilePdfPreviewService(
      resources: fixture.resources,
      renderPreview: (_) async {
        renders++;
        return <int>[1];
      },
    );

    expect(
      await service.resolve(
        fileObjectTypeId: fixture.fileObjectTypeId,
        fileObjectId: fixture.fileObjectId,
      ),
      isNull,
    );
    expect(renders, 0);
  });

  test('empty native preview is treated as unavailable', () async {
    final fixture = await _Fixture.create(
      filename: 'paper.pdf',
      bytes: '%PDF-1.7\nbody'.codeUnits,
      contentType: 'application/pdf',
    );
    addTearDown(fixture.dispose);
    final service = CanonicalFilePdfPreviewService(
      resources: fixture.resources,
      renderPreview: (_) async => const <int>[],
    );

    expect(
      await service.resolve(
        fileObjectTypeId: fixture.fileObjectTypeId,
        fileObjectId: fixture.fileObjectId,
      ),
      isNull,
    );
  });
}

class _Fixture {
  _Fixture({
    required this.root,
    required this.database,
    required this.resources,
    required this.fileObjectTypeId,
    required this.fileObjectId,
    required this.filePath,
  });

  final Directory root;
  final AppDatabase database;
  final FileManagedResourceResolver resources;
  final int fileObjectTypeId;
  final int fileObjectId;
  final String filePath;

  static Future<_Fixture> create({
    required String filename,
    required List<int> bytes,
    required String contentType,
  }) async {
    final root = await Directory.systemTemp.createTemp('file_pdf_preview_');
    final managed = File('${root.path}/attachments/$filename');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes(bytes);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
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
      contentType: contentType,
    );

    return _Fixture(
      root: root,
      database: database,
      resources: FileManagedResourceResolver(
        objectStore,
        pathResolver: ProfilePathResolver(root.path),
      ),
      fileObjectTypeId: definition.objectType.id,
      fileObjectId: fileObject.id,
      filePath: managed.path,
    );
  }

  Future<void> dispose() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
