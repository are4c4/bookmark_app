import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'real Weblinks masonry Gallery uses managed media geometry and preserves Object opening',
      (tester) async {
    Future<void> pumpUntilVisible(Finder finder) async {
      for (var attempt = 0; attempt < 30; attempt += 1) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) return;
      }
      expect(finder, findsOneWidget);
    }

    final directory =
        await Directory.systemTemp.createTemp('real_weblink_gallery_');
    addTearDown(() => directory.delete(recursive: true));
    final portraitFile = File('${directory.path}/portrait.png');
    final landscapeFile = File('${directory.path}/landscape.png');
    // The Gallery must size cards from persisted Image metadata, not from an
    // image codec. Existing but deliberately undecodable files keep this
    // real-host regression focused on that contract while production rendering
    // safely falls back through Image.file's errorBuilder.
    await portraitFile.writeAsBytes(const <int>[0]);
    await landscapeFile.writeAsBytes(const <int>[0]);

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
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final portraitWeblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/portrait',
      title: 'Portrait Weblink',
    );
    final landscapeWeblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/landscape',
      title: 'Landscape Weblink',
    );
    final noMediaWeblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/no-media',
      title: 'No Media Weblink',
    );
    final portraitImage = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: portraitFile.path,
      pixelWidth: 600,
      pixelHeight: 1200,
    );
    final landscapeImage = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: landscapeFile.path,
      pixelWidth: 1200,
      pixelHeight: 600,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    await mutations.setRelation(
      objectId: portraitWeblink.id,
      property: schema.representativeImageProperty,
      targetObjectIds: <int>[portraitImage.id],
    );
    await mutations.setRelation(
      objectId: landscapeWeblink.id,
      property: schema.representativeImageProperty,
      targetObjectIds: <int>[landscapeImage.id],
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
      name: 'Masonry',
      layoutType: 'gallery',
      settings: const <String, dynamic>{'galleryMode': 'masonry'},
    );

    final destination = (await genericStore.listDatabases(workspaceId))
        .singleWhere((item) => item.id == schema.weblinkObjectTypeId);
    expect(destination.name, 'Weblinks');

    tester.view.physicalSize = const Size(1600, 1400);
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

    final masonry = find.byKey(const ValueKey('object-gallery-masonry'));
    await pumpUntilVisible(masonry);
    expect(masonry, findsOneWidget);
    expect(find.text('Portrait Weblink'), findsOneWidget);
    expect(find.text('Landscape Weblink'), findsOneWidget);
    expect(find.text('No Media Weblink'), findsOneWidget);

    final portrait = find.byKey(
      ValueKey('weblink-gallery-media-ratio-${portraitWeblink.id}'),
    );
    final landscape = find.byKey(
      ValueKey('weblink-gallery-media-ratio-${landscapeWeblink.id}'),
    );
    final fallback = find.byKey(
      ValueKey('weblink-gallery-media-fallback-${noMediaWeblink.id}'),
    );
    await pumpUntilVisible(portrait);
    expect(portrait, findsOneWidget);
    expect(landscape, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(
      tester.getSize(portrait).height,
      greaterThan(tester.getSize(landscape).height),
    );
    expect(tester.getSize(fallback).height, 160);

    await tester.tap(find.text('Portrait Weblink'));
    final sidePeek = find.byKey(
      ValueKey('side-peek-open-full-page-${portraitWeblink.id}'),
    );
    await pumpUntilVisible(sidePeek);
    expect(sidePeek, findsOneWidget);

    expect(
      (await objectStore.listObjects(schema.weblinkObjectTypeId))
          .map((object) => object.id)
          .toSet(),
      <int>{portraitWeblink.id, landscapeWeblink.id, noMediaWeblink.id},
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
