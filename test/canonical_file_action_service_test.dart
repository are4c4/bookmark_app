import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/canonical_file_action_service.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open and reveal receive the resolved existing canonical File path',
      () async {
    final root = await Directory.systemTemp.createTemp('file_action_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/files/report.pdf');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes(const <int>[1, 2, 3]);

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
      originalFilename: 'report.pdf',
      contentType: 'application/pdf',
      sizeBytes: 3,
    );

    final calls = <String>[];
    final actions = CanonicalFileActionService(
      resources: CanonicalFileManagedResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
        pathResolver: database.pathResolver,
      ),
      openPath: (path) async {
        calls.add('open:$path');
        return true;
      },
      revealPath: (path) async {
        calls.add('reveal:$path');
        return true;
      },
    );

    await actions.open(
      fileObjectTypeId: definition.objectType.id,
      fileObjectId: fileObject.id,
    );
    await actions.reveal(
      fileObjectTypeId: definition.objectType.id,
      fileObjectId: fileObject.id,
    );

    expect(calls, <String>['open:${managed.path}', 'reveal:${managed.path}']);
  });

  test('missing canonical File never invokes an OS action', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
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
      filePath: '/definitely/missing/report.pdf',
    );
    var actionCalls = 0;
    final actions = CanonicalFileActionService(
      resources: CanonicalFileManagedResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
        pathResolver: database.pathResolver,
      ),
      openPath: (path) async {
        actionCalls++;
        return true;
      },
      revealPath: (path) async {
        actionCalls++;
        return true;
      },
    );

    await expectLater(
      actions.open(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      ),
      throwsA(isA<CanonicalFileUnavailableException>()),
    );
    expect(actionCalls, 0);
  });

  test('OS action failure is user-safe and does not expose the file path',
      () async {
    final root = await Directory.systemTemp.createTemp('file_action_failure_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/secret-name.pdf');
    await managed.writeAsBytes(const <int>[1]);

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
    );
    final actions = CanonicalFileActionService(
      resources: CanonicalFileManagedResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
        pathResolver: database.pathResolver,
      ),
      openPath: (path) async => false,
      revealPath: (path) async => false,
    );

    try {
      await actions.reveal(
        fileObjectTypeId: definition.objectType.id,
        fileObjectId: fileObject.id,
      );
      fail('expected reveal failure');
    } on CanonicalFileActionException catch (error) {
      expect(error.toString(), isNot(contains(managed.path)));
      expect(error.toString(), isNot(contains('secret-name.pdf')));
    }
  });
}
