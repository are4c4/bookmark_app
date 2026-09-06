import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real Images host deletes solely owned managed file with Object',
      (tester) async {
    final root = await Directory.systemTemp.createTemp('image_delete_host_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final photoDirectory = Directory('${root.path}/photos');
    await photoDirectory.create(recursive: true);
    final managedFile = File('${photoDirectory.path}/delete-me.png');
    await managedFile.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
        'AAAAC0lEQVR42mP8/x8AAusB9Y9ZsXcAAAAASUVORK5CYII=',
      ),
    );
    final backup = File('${managedFile.path}.bookmark_original');
    await backup.writeAsBytes(const <int>[1, 2, 3]);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
      profileDirectoryPath: root.path,
    );
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final image = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      title: 'Delete managed image',
      originalFilename: 'delete-me.png',
    );

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GenericDatabasePage(
          repository: repository,
          databaseId: definition.objectType.id,
          onDatabaseChanged: () {},
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text(image.title));

    await tester.tap(find.text(image.title).first);
    await _pumpUntilFound(tester, find.byTooltip('削除'));
    await tester.tap(find.byTooltip('削除'));
    await _pumpUntilFileMissing(tester, managedFile);

    expect(await managedFile.exists(), isFalse);
    expect(await backup.exists(), isFalse);
    expect(
      (await objectStore.listObjects(definition.objectType.id))
          .map((object) => object.id),
      isNot(contains(image.id)),
    );

    // Dispose the real host before database teardown so live Drift
    // subscriptions cannot keep the test process alive after assertions pass.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Expected widget did not appear within 5 seconds.');
}

Future<void> _pumpUntilFileMissing(WidgetTester tester, File file) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (!await file.exists()) return;
  }
  throw TestFailure('Managed image file was not deleted within 5 seconds.');
}
