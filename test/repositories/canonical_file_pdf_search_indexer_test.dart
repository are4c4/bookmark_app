import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:bookmark_app/services/canonical_file_pdf_search_indexer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global Object search reconciles PDF text and focused refresh clears stale tokens',
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
    final globalSearch = ObjectGlobalSearchService(
      genericStore,
      pdfSearchIndexer: indexer,
    );

    await globalSearch.rebuildWorkspace(workspaceId);
    expect(readerCalls, 1);
    expect(
      (await globalSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'legacypdfsearchtoken',
      ))
          .map((hit) => hit.object.id),
      contains(fileObject.id),
      reason: 'workspace rebuild must reconcile PDF-derived text automatically',
    );

    extractedText = 'CurrentPdfSearchToken';
    expect(
      await globalSearch.refreshFilePdfText(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      isTrue,
    );
    expect(readerCalls, 2);
    expect(
      await globalSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'legacypdfsearchtoken',
      ),
      isEmpty,
      reason: 're-extraction must replace stale PDF-derived tokens',
    );
    expect(
      (await globalSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'currentpdfsearchtoken',
      ))
          .map((hit) => hit.object.id),
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
      await globalSearch.refreshFilePdfText(
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
      await globalSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'currentpdfsearchtoken',
      ),
      isEmpty,
      reason: 'non-PDF refresh must clear the previous pdf-text contribution',
    );
    expect(
      (await globalSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'research',
      ))
          .map((hit) => hit.object.id),
      contains(fileObject.id),
      reason: 'focused PDF refresh must preserve ordinary File metadata search',
    );
  });

  test('corrupt File schema does not block healthy Global Search rebuild', () async {
    final root = await Directory.systemTemp.createTemp('pdf_search_corrupt_file_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/attachments/corruptible.pdf');
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
      title: 'Corruptible PDF object',
      originalFilename: 'corruptible.pdf',
      contentType: 'application/pdf',
    );
    final healthyTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Healthy Search Type',
    );
    final healthyObjectId = await objectStore.createObject(
      objectTypeId: healthyTypeId,
      title: 'HealthyBeforeFileCorruption',
    );

    var readerCalls = 0;
    final indexer = CanonicalFilePdfSearchIndexer.forStore(
      genericStore,
      readText: (path) async {
        readerCalls++;
        expect(path, managed.path);
        return 'CorruptiblePdfDerivedToken';
      },
    );
    final globalSearch = ObjectGlobalSearchService(
      genericStore,
      pdfSearchIndexer: indexer,
    );

    await globalSearch.rebuildWorkspace(workspaceId);
    expect(readerCalls, 1);
    expect(
      (await globalSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'corruptiblepdfderived',
      ))
          .map((hit) => hit.object.id),
      contains(fileObject.id),
    );

    final corruptProperty = definition.objectType.properties.firstWhere(
      (property) => property.name == FileObjectService.originalFilenamePropertyName,
    );
    await database.customStatement(
      'UPDATE generic_properties SET type = ? WHERE id = ?',
      ['futureRichText', corruptProperty.id],
    );
    await objectStore.renameObject(
      healthyObjectId,
      'HealthyAfterFileCorruption',
    );

    await globalSearch.rebuildWorkspace(workspaceId);
    expect(
      readerCalls,
      1,
      reason: 'corrupt File schema must skip optional PDF reconciliation',
    );
    expect(
      await globalSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'corruptiblepdfderived',
      ),
      isEmpty,
      reason: 'corrupt File ObjectType must be omitted from the FTS rebuild',
    );
    expect(
      (await globalSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'healthyafterfilecorruption',
      ))
          .map((hit) => hit.object.id),
      contains(healthyObjectId),
      reason: 'healthy ObjectTypes must still rebuild through Global Search',
    );

    await database.customStatement(
      'UPDATE generic_properties SET type = ? WHERE id = ?',
      [corruptProperty.storageType, corruptProperty.id],
    );
    await globalSearch.rebuildWorkspace(workspaceId);
    expect(readerCalls, 2);
    expect(
      (await globalSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'corruptiblepdfderived',
      ))
          .map((hit) => hit.object.id),
      contains(fileObject.id),
      reason: 'repairing File schema must restore PDF-derived indexing',
    );
  });
}
