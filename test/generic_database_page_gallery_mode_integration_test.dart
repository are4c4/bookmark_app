import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkRepository repository;
  late ObjectStore objectStore;
  late DatabaseViewStore viewStore;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceStore = WorkspaceStore(database);
    workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    objectStore = ObjectStore(GenericDatabaseStore(database));
    viewStore = DatabaseViewStore(database);
  });

  tearDown(() => database.close());

  Future<void> pumpPage(WidgetTester tester, int databaseId) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GenericDatabasePage(
          repository: repository,
          databaseId: databaseId,
          onDatabaseChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'real Gallery switches persisted fixed/masonry geometry without changing Objects',
      (tester) async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Gallery items',
      icon: '🖼️',
    );
    final firstId = await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Portrait item',
    );
    final secondId = await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Landscape item',
    );
    final definition = DatabaseDefinition(
      key: 'custom:$databaseId',
      label: 'Gallery items',
      icon: Icons.grid_view,
      properties: const <DatabasePropertyDefinition>[],
      defaultLayout: 'gallery',
      supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
    );
    await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Gallery',
      layoutType: 'gallery',
    );

    await pumpPage(tester, databaseId);

    expect(
      find.byKey(const ValueKey('object-gallery-fixed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-gallery-masonry')),
      findsNothing,
    );
    expect(find.text('Portrait item'), findsOneWidget);
    expect(find.text('Landscape item'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gallery-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('メイソンリー').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('object-gallery-masonry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-gallery-fixed')),
      findsNothing,
    );
    expect(find.text('Portrait item'), findsOneWidget);
    expect(find.text('Landscape item'), findsOneWidget);

    final persisted = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .single;
    expect(persisted.layoutType, 'gallery');
    expect(
      const DatabaseViewGalleryAdapter().decode(persisted),
      GalleryViewMode.masonry,
    );

    final objectIds = (await objectStore.listObjects(databaseId))
        .map((object) => object.id)
        .toSet();
    expect(objectIds, <int>{firstId, secondId});
  });
}
