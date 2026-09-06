import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:bookmark_app/services/canonical_file_pdf_search_indexer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical PDF extraction replaces derived tokens and clears when no longer PDF',
      () async {
    final root = await Directory.systemTemp.createTemp('pdf_search_pipeline_');
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
      title: 'Canonical PDF object',
      originalFilename: 'research-note.pdf',
      contentType: 'application/octet-stream',
    );

    var extractedText = 'LegacyPdfSearchToken';
    var readerCalls = 0;
    final indexer = CanonicalFilePdfSearchIndexer.forStore(
      genericStore,
      readText: (path) async {
        readerCalls++;
        expect(path, managed.path);
        return extractedText;
      },
    );
    final search = ObjectSearchRepository(genericStore);

    expect(
      await indexer.refresh(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      isTrue,
    );
    expect(readerCalls, 1);
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'legacypdfsearchtoken',
      ))
          .map((hit) => hit.objectId),
      contains(fileObject.id),
    );

    extractedText = 'CurrentPdfSearchToken';
    expect(
      await indexer.refresh(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      isTrue,
    );
    expect(readerCalls, 2);
    expect(
      await search.search(
        workspaceId: workspaceId,
        rawQuery: 'legacypdfsearchtoken',
      ),
      isEmpty,
      reason: 're-extraction must replace stale PDF-derived tokens',
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'currentpdfsearchtoken',
      ))
          .map((hit) => hit.objectId),
      contains(fileObject.id),
    );

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
    expect(
      await indexer.refresh(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      isFalse,
    );
    expect(
      readerCalls,
      2,
      reason: 'content-first classification must not invoke PDF reader for PNG',
    );
    expect(
      await search.search(
        workspaceId: workspaceId,
        rawQuery: 'currentpdfsearchtoken',
      ),
      isEmpty,
      reason: 'non-PDF refresh must clear the previous pdf-text contribution',
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'research'))
          .map((hit) => hit.objectId),
      contains(fileObject.id),
      reason: 'focused PDF refresh must preserve ordinary File metadata search',
    );
  });
}
