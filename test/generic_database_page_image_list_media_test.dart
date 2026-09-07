import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  testWidgets('real Images List hosts canonical Image leading media',
      (tester) async {
    Future<void> pumpUntilVisible(Finder finder) async {
      for (var attempt = 0; attempt < 30; attempt += 1) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) return;
      }
      expect(finder, findsWidgets);
    }

    final database = AppDatabase.forTesting(NativeDatabase.memory());
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

    final tempDirectory =
        await Directory.systemTemp.createTemp('image_list_media_host_');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final file = File('${tempDirectory.path}/list.png');
    await file.writeAsBytes(
      image.encodePng(image.Image(width: 3, height: 2)),
    );
    final object = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: file.path,
      originalFilename: 'list.png',
      contentType: 'image/png',
      pixelWidth: 3,
      pixelHeight: 2,
    );
    final definition = await images.ensureDefinition(workspaceId);

    await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: DatabaseDefinition(
        key: 'custom:${definition.objectType.id}',
        label: 'Images',
        icon: Icons.image_outlined,
        properties: const <DatabasePropertyDefinition>[],
        defaultLayout: 'list',
        supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
      ),
      name: 'List',
      layoutType: 'list',
    );

    final destination = (await genericStore.listDatabases(workspaceId))
        .singleWhere((item) => item.id == definition.objectType.id);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GenericDatabasePage(
          repository: repository,
          databaseId: destination.id,
          onDatabaseChanged: () {},
        ),
      ),
    );

    final media = find.byKey(
      ValueKey('system-object-list-media-image-${object.id}'),
    );
    await pumpUntilVisible(media);
    expect(media, findsOneWidget);
    expect(find.text(object.title), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
