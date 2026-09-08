import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_default_provisioning_service.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Weblinks seed one shared List View', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final weblinkType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
      name: 'リンク',
      icon: '🔗',
    );
    final viewStore = DatabaseViewStore(database);
    final service = DatabaseViewDefaultProvisioningService.fromViewStore(
      viewStore,
    );
    final definition = DatabaseDefinition(
      key: 'custom:${weblinkType.id}',
      label: 'Weblinks',
      icon: Icons.link,
      properties: const <DatabasePropertyDefinition>[],
      defaultLayout: 'table',
      supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
    );

    final view = await service.ensureDefaultView(
      workspaceId: workspaceId,
      definition: definition,
    );

    expect(view.name, 'リスト');
    expect(view.layoutType, 'list');
    expect(view.settings, isEmpty);
    expect(
      await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: definition.key,
      ),
      hasLength(1),
    );
  });

  test('existing Weblinks View is never reseeded or reset', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final weblinkType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
      name: 'リンク',
      icon: '🔗',
    );
    final viewStore = DatabaseViewStore(database);
    final service = DatabaseViewDefaultProvisioningService.fromViewStore(
      viewStore,
    );
    final definition = DatabaseDefinition(
      key: 'custom:${weblinkType.id}',
      label: 'Weblinks',
      icon: Icons.link,
      properties: const <DatabasePropertyDefinition>[],
      defaultLayout: 'table',
      supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
    );

    final seeded = await service.ensureDefaultView(
      workspaceId: workspaceId,
      definition: definition,
    );
    final customized = seeded.copyWith(
      name: 'My Gallery',
      layoutType: 'gallery',
      settings: const <String, dynamic>{'customized': true},
    );
    await viewStore.updateView(customized);

    final reopened = await service.ensureDefaultView(
      workspaceId: workspaceId,
      definition: definition,
    );
    final views = await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );

    expect(views, hasLength(1));
    expect(reopened.id, seeded.id);
    expect(reopened.name, 'My Gallery');
    expect(reopened.layoutType, 'gallery');
    expect(reopened.settings, const <String, dynamic>{'customized': true});
  });

  test('canonical Images seed one masonry direct-image Gallery View', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: '画像',
      icon: '🖼️',
    );
    final viewStore = DatabaseViewStore(database);
    final service = DatabaseViewDefaultProvisioningService.fromViewStore(
      viewStore,
    );
    final definition = DatabaseDefinition(
      key: 'custom:${imageType.id}',
      label: 'Images',
      icon: Icons.image_outlined,
      properties: const <DatabasePropertyDefinition>[],
      defaultLayout: 'table',
      supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
    );

    final view = await service.ensureDefaultView(
      workspaceId: workspaceId,
      definition: definition,
    );

    expect(view.name, 'ギャラリー');
    expect(view.layoutType, 'gallery');
    expect(
      const DatabaseViewGalleryAdapter().decode(view),
      GalleryViewMode.masonry,
    );
    expect(
      const DatabaseViewGalleryAdapter().decodeCoverSource(view),
      const GalleryCoverSource.directImage(),
    );
    expect(
      await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: definition.key,
      ),
      hasLength(1),
    );
  });

  test('existing Images View is never reseeded or reset', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: '画像',
      icon: '🖼️',
    );
    final viewStore = DatabaseViewStore(database);
    final service = DatabaseViewDefaultProvisioningService.fromViewStore(
      viewStore,
    );
    final definition = DatabaseDefinition(
      key: 'custom:${imageType.id}',
      label: 'Images',
      icon: Icons.image_outlined,
      properties: const <DatabasePropertyDefinition>[],
      defaultLayout: 'table',
      supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
    );

    final seeded = await service.ensureDefaultView(
      workspaceId: workspaceId,
      definition: definition,
    );
    final customized = seeded.copyWith(
      name: 'My Table',
      layoutType: 'table',
      settings: const <String, dynamic>{'customized': true},
    );
    await viewStore.updateView(customized);

    final reopened = await service.ensureDefaultView(
      workspaceId: workspaceId,
      definition: definition,
    );
    final views = await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );

    expect(views, hasLength(1));
    expect(reopened.id, seeded.id);
    expect(reopened.name, 'My Table');
    expect(reopened.layoutType, 'table');
    expect(reopened.settings, const <String, dynamic>{'customized': true});
  });

  test('ordinary ObjectTypes keep the Database definition default', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Plant',
      icon: '🪴',
    );
    final viewStore = DatabaseViewStore(database);
    final service = DatabaseViewDefaultProvisioningService.fromViewStore(
      viewStore,
    );
    final definition = DatabaseDefinition(
      key: 'custom:$objectTypeId',
      label: 'Plant',
      icon: Icons.local_florist_outlined,
      properties: const <DatabasePropertyDefinition>[],
      defaultLayout: 'table',
      supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
    );

    final view = await service.ensureDefaultView(
      workspaceId: workspaceId,
      definition: definition,
    );

    expect(view.name, 'すべて');
    expect(view.layoutType, 'table');
    expect(view.settings, isEmpty);
  });
}
