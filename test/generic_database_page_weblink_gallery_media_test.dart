import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/features/database/presentation/widgets/weblink_gallery_media.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'real Weblinks masonry Gallery hosts managed media and preserves Object opening',
      (tester) async {
    await _exerciseWeblinkGalleryMode(
      tester,
      galleryMode: 'masonry',
      galleryKey: const ValueKey('object-gallery-masonry'),
      firstMediaKeyPrefix: 'weblink-gallery-media-fallback',
    );
  });

  testWidgets(
      'real Weblinks fixed Gallery hosts managed media and preserves Object opening',
      (tester) async {
    await _exerciseWeblinkGalleryMode(
      tester,
      galleryMode: 'fixed',
      galleryKey: const ValueKey('object-gallery-fixed'),
      firstMediaKeyPrefix: 'weblink-gallery-media-fixed',
    );
  });
}

Future<void> _exerciseWeblinkGalleryMode(
  WidgetTester tester, {
  required String galleryMode,
  required ValueKey<String> galleryKey,
  required String firstMediaKeyPrefix,
}) async {
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
  final defaultsStore = ObjectTypeDefaultsStore(genericStore);
  final systemObjects = SystemObjectStore(
    database: database,
    objectStore: objectStore,
  );
  final schema = await WeblinkImageSchemaService(
    systemObjects: systemObjects,
    defaultsStore: defaultsStore,
  ).ensureDefinition(workspaceId);
  final weblinks = WeblinkObjectService(
    systemObjects: systemObjects,
    defaultsStore: defaultsStore,
  );
  final first = await weblinks.findOrCreate(
    workspaceId: workspaceId,
    url: 'https://example.com/first',
    title: 'First Weblink',
  );
  final second = await weblinks.findOrCreate(
    workspaceId: workspaceId,
    url: 'https://example.com/second',
    title: 'Second Weblink',
  );
  final third = await weblinks.findOrCreate(
    workspaceId: workspaceId,
    url: 'https://example.com/third',
    title: 'Third Weblink',
  );

  final definition = DatabaseDefinition(
    key: 'custom:${schema.weblinkObjectTypeId}',
    label: 'Weblinks',
    icon: Icons.link,
    properties: const <DatabasePropertyDefinition>[],
    defaultLayout: 'gallery',
    supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
  );
  await DatabaseViewStore(database).createView(
    workspaceId: workspaceId,
    definition: definition,
    name: galleryMode == 'masonry' ? 'Masonry' : 'Fixed',
    layoutType: 'gallery',
    settings: <String, dynamic>{'galleryMode': galleryMode},
  );

  final destination = (await genericStore.listDatabases(workspaceId))
      .singleWhere((item) => item.id == schema.weblinkObjectTypeId);
  expect(destination.name, 'Weblinks');

  tester.view.physicalSize = const Size(1600, 1200);
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

  final gallery = find.byKey(galleryKey);
  await pumpUntilVisible(gallery);
  expect(gallery, findsOneWidget);
  expect(find.text('First Weblink'), findsOneWidget);
  expect(find.text('Second Weblink'), findsOneWidget);
  expect(find.text('Third Weblink'), findsOneWidget);

  // This real-host layer intentionally has no managed files. Resolution and
  // persisted portrait/landscape geometry are covered by a normal async test
  // so OS file I/O does not run inside WidgetTester FakeAsync. Here we prove
  // both real Gallery geometries wire the same shared media component.
  expect(find.byType(WeblinkGalleryMedia), findsNWidgets(3));
  final firstFrame = find.byKey(
    ValueKey('$firstMediaKeyPrefix-${first.id}'),
  );
  await pumpUntilVisible(firstFrame);
  expect(firstFrame, findsOneWidget);

  await tester.tap(find.text('First Weblink'));
  final sidePeek = find.byKey(
    ValueKey('side-peek-open-full-page-${first.id}'),
  );
  await pumpUntilVisible(sidePeek);
  expect(sidePeek, findsOneWidget);

  expect(
    (await objectStore.listObjects(schema.weblinkObjectTypeId))
        .map((object) => object.id)
        .toSet(),
    <int>{first.id, second.id, third.id},
  );

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
