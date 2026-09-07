import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/canonical_file_export_service.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory profile;
  late AppDatabase database;
  late ObjectStore objectStore;
  late FileObjectService files;
  late FileObjectDefinition definition;
  late CanonicalFileExportService exporter;
  late File managedSource;
  late int fileObjectId;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('canonical_file_export_');
    profile = Directory('${root.path}/profile');
    await profile.create(recursive: true);
    managedSource = File('${profile.path}/attachments/report.pdf');
    await managedSource.parent.create(recursive: true);
    await managedSource.writeAsBytes(const <int>[1, 3, 3, 7, 9]);

    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: profile.path,
    );
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    files = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    definition = await files.ensureDefinition(workspaceId);
    final fileObject = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedSource.path,
      originalFilename: 'report.pdf',
      contentType: 'application/pdf',
      sizeBytes: 5,
    );
    fileObjectId = fileObject.id;
    exporter = CanonicalFileExportService(
      resources: CanonicalFileManagedResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
        pathResolver: database.pathResolver,
      ),
    );
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('exports resolved canonical File without changing source identity', () async {
    final exportDirectory = Directory('${root.path}/exports');
    await exportDirectory.create();
    final destination = File('${exportDirectory.path}/report.pdf');
    final before = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == fileObjectId);
    final storedPathBefore = before.values[definition.fileProperty.id];

    await exporter.exportTo(
      fileObjectTypeId: definition.objectType.id,
      fileObjectId: fileObjectId,
      destinationPath: destination.path,
    );

    expect(await destination.readAsBytes(), <int>[1, 3, 3, 7, 9]);
    expect(await managedSource.readAsBytes(), <int>[1, 3, 3, 7, 9]);
    final after = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == fileObjectId);
    expect(after.values[definition.fileProperty.id], storedPathBefore);
  });

  test('existing destination is never overwritten', () async {
    final destination = File('${root.path}/existing.pdf');
    await destination.writeAsBytes(const <int>[8, 8, 8]);

    await expectLater(
      exporter.exportTo(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObjectId,
        destinationPath: destination.path,
      ),
      throwsA(
        isA<CanonicalFileExportException>().having(
          (error) => error.toString(),
          'message',
          '書き出し先にはすでにファイルまたはフォルダがあります。',
        ),
      ),
    );

    expect(await destination.readAsBytes(), <int>[8, 8, 8]);
    expect(await managedSource.readAsBytes(), <int>[1, 3, 3, 7, 9]);
  });

  test('missing managed source fails before creating a destination', () async {
    await managedSource.delete();
    final destination = File('${root.path}/missing-source-export.pdf');

    await expectLater(
      exporter.exportTo(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObjectId,
        destinationPath: destination.path,
      ),
      throwsA(isA<CanonicalFileExportUnavailableException>()),
    );

    expect(await destination.exists(), isFalse);
  });

  test('copy failure is path-redacted and never changes the managed source',
      () async {
    final destination = File('${root.path}/missing/folder/report.pdf');

    Object? failure;
    try {
      await exporter.exportTo(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObjectId,
        destinationPath: destination.path,
      );
    } catch (error) {
      failure = error;
    }

    expect(failure, isA<CanonicalFileExportException>());
    expect(failure.toString(), 'ファイルを書き出せませんでした。');
    expect(failure.toString(), isNot(contains(root.path)));
    expect(await destination.exists(), isFalse);
    expect(await managedSource.readAsBytes(), <int>[1, 3, 3, 7, 9]);
  });
}
