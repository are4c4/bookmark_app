import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/canonical_weblink_capture_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('direct capture reuses normalized URL without Bookmark authority',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final harness = _CaptureHarness(database);

    final first = await harness.capture.capture(
      workspaceId: workspaceId,
      url: 'HTTPS://Example.COM:443/a/../article?x=1#part',
    );
    final second = await harness.capture.capture(
      workspaceId: workspaceId,
      url: 'https://example.com/article?x=1#part',
      title: 'A later requested title',
    );
    final definition = await harness.weblinks.ensureDefinition(workspaceId);

    expect(second.id, first.id);
    expect(
      await harness.objectStore.listObjects(definition.objectType.id),
      hasLength(1),
    );
    final bookmarkCount = await database
        .customSelect('SELECT COUNT(*) AS count FROM bookmarks')
        .getSingle();
    expect(bookmarkCount.read<int>('count'), 0);
  });

  test('canonical URL collision fails closed without creating another target',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final harness = _CaptureHarness(database);
    final definition = await harness.weblinks.ensureDefinition(workspaceId);

    await harness.weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article',
      title: 'First canonical candidate',
    );
    final duplicateId = await harness.objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Second canonical candidate',
    );
    await harness.objectStore.setPropertyValue(
      objectId: duplicateId,
      property: definition.urlProperty,
      value: 'HTTPS://Example.COM:443/article',
    );

    await expectLater(
      harness.capture.capture(
        workspaceId: workspaceId,
        url: 'https://example.com/article',
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      await harness.objectStore.listObjects(definition.objectType.id),
      hasLength(2),
    );
  });

  test('first concurrent equivalent captures create one definition and target',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final harness = _CaptureHarness(database);

    final captured = await Future.wait([
      harness.capture.capture(
        workspaceId: workspaceId,
        url: 'HTTPS://Example.COM:443/a/../article',
      ),
      CanonicalWeblinkCaptureService(weblinks: harness.weblinks).capture(
        workspaceId: workspaceId,
        url: 'https://example.com/article',
      ),
    ]);
    final definition = await harness.weblinks.ensureDefinition(workspaceId);

    expect(captured[1].id, captured[0].id);
    expect(
      await harness.objectStore.listObjects(definition.objectType.id),
      hasLength(1),
    );
    final systemTypes = (await harness.objectStore.listObjectTypes(workspaceId))
        .where((type) => type.id == definition.objectType.id)
        .toList(growable: false);
    expect(systemTypes, hasLength(1));
  });

  test('capture reuses persisted canonical identity after database restart',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'canonical_weblink_capture_restart_',
    );
    final databaseFile = File('${directory.path}/app.sqlite');
    AppDatabase? database;
    try {
      database = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
        profileDirectoryPath: directory.path,
      );
      final workspaceId = await WorkspaceStore(database).initialize();
      final firstHarness = _CaptureHarness(database);
      final first = await firstHarness.capture.capture(
        workspaceId: workspaceId,
        url: 'HTTPS://Example.COM:443/a/../persisted',
      );
      final firstId = first.id;
      await database.close();
      database = null;

      database = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
        profileDirectoryPath: directory.path,
      );
      final restartedWorkspaceId = await WorkspaceStore(database).initialize();
      final restartedHarness = _CaptureHarness(database);
      final second = await restartedHarness.capture.capture(
        workspaceId: restartedWorkspaceId,
        url: 'https://example.com/persisted',
      );
      final definition =
          await restartedHarness.weblinks.ensureDefinition(restartedWorkspaceId);

      expect(restartedWorkspaceId, workspaceId);
      expect(second.id, firstId);
      expect(
        await restartedHarness.objectStore.listObjects(definition.objectType.id),
        hasLength(1),
      );
    } finally {
      if (database != null) {
        await database.close();
      }
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });

  test('invalid direct capture fails before creating a Weblink ObjectType',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final harness = _CaptureHarness(database);

    await expectLater(
      harness.capture.capture(
        workspaceId: workspaceId,
        url: 'example.com/no-scheme',
      ),
      throwsArgumentError,
    );

    expect(
      await harness.systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ),
      isNull,
    );
  });
}

class _CaptureHarness {
  _CaptureHarness(AppDatabase database) {
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    capture = CanonicalWeblinkCaptureService(weblinks: weblinks);
  }

  late final GenericDatabaseStore genericStore;
  late final ObjectStore objectStore;
  late final SystemObjectStore systemObjects;
  late final WeblinkObjectService weblinks;
  late final CanonicalWeblinkCaptureService capture;
}
