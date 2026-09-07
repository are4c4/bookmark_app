import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'real generic Gallery persists an Image Relation as its View cover source',
      (tester) async {
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
    final viewStore = DatabaseViewStore(database);

    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final plantTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Plant',
      icon: '🪴',
    );
    final photoPropertyId = await objectStore.createRelationProperty(
      objectTypeId: plantTypeId,
      name: 'Photo',
      targetObjectTypeId: imageType.id,
      multiple: false,
    );
    await objectStore.createObject(
      objectTypeId: plantTypeId,
      title: 'Monstera',
    );

    final definition = DatabaseDefinition(
      key: 'custom:$plantTypeId',
      label: 'Plant',
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

    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GenericDatabasePage(
          repository: repository,
          databaseId: plantTypeId,
          onDatabaseChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monstera'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('gallery-cover-source-menu')),
      findsOneWidget,
    );
    expect(find.text('カバー: なし'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('database-gallery-cover-none')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('gallery-cover-source-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo · Image'));
    await tester.pumpAndSettle();

    final persisted = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .single;
    expect(
      const DatabaseViewGalleryAdapter().decodeCoverSource(persisted),
      GalleryCoverSource.imageRelation(photoPropertyId),
    );
    expect(find.text('カバー: Photo · Image'), findsOneWidget);
  });
}
