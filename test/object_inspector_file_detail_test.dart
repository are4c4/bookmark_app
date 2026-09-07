import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected widget did not appear within the bounded pump window.');
}

void main() {
  testWidgets('canonical File detail exposes native File actions', (tester) async {
    final root = await Directory.systemTemp.createTemp('object_inspector_file_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/attachments/readme.txt');
    await managed.parent.create(recursive: true);
    await managed.writeAsString('hello');

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
    final file = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      originalFilename: 'readme.txt',
      contentType: 'text/plain',
    );

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: file.id,
        ),
      ),
    );

    final openFinder = find.byKey(ValueKey('object-file-open-${file.id}'));
    await _pumpUntilFound(tester, openFinder);

    expect(openFinder, findsOneWidget);
    expect(
      find.byKey(ValueKey('object-file-reveal-${file.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('object-file-export-${file.id}')),
      findsOneWidget,
    );
  });

  testWidgets('custom file-shaped Object detail has no native File actions',
      (tester) async {
    final root = await Directory.systemTemp.createTemp('object_inspector_custom_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/attachments/readme.txt');
    await managed.parent.create(recursive: true);
    await managed.writeAsString('hello');

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);

    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Document reference',
    );
    final customFilePropertyId = await objectStore.createProperty(
      objectTypeId: customTypeId,
      name: 'File',
      type: ObjectPropertyType.file,
    );
    final customType = (await objectStore.getObjectType(customTypeId))!;
    final customFileProperty = customType.properties.singleWhere(
      (property) => property.id == customFilePropertyId,
    );
    final customObjectId = await objectStore.createObject(
      objectTypeId: customTypeId,
      title: 'Not a built-in File',
    );
    await objectStore.setPropertyValue(
      objectId: customObjectId,
      property: customFileProperty,
      value: database.pathResolver.toStoredPath(managed.path),
    );

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: customObjectId,
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Not a built-in File'));

    expect(find.byKey(ValueKey('object-file-open-$customObjectId')), findsNothing);
    expect(
      find.byKey(ValueKey('object-file-reveal-$customObjectId')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('object-file-export-$customObjectId')),
      findsNothing,
    );
  });
}
