import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_gallery_cover_compatibility_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseViewConfig _view({Map<String, dynamic> settings = const {}}) =>
    DatabaseViewConfig(
      id: 1,
      workspaceId: 1,
      databaseKey: 'custom:1',
      name: 'Gallery',
      layoutType: 'gallery',
      filters: const {},
      sorts: const [],
      visibleProperties: const [],
      propertyOrder: const [],
      settings: settings,
      sortOrder: 0,
    );

void main() {
  test('unconfigured system Image keeps direct media compatibility', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final image = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );

    final source = await DatabaseViewGalleryCoverCompatibilityService(
      objectStore: objectStore,
      systemObjects: systemObjects,
    ).effectiveSource(view: _view(), objectTypeId: image.id);

    expect(source, const GalleryCoverSource.directImage());
  });

  test('unconfigured system Weblink prefers its schema Image Relation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final image = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final weblink = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
      name: 'Weblink',
      icon: '🔗',
    );
    final representative = await systemObjects.ensureRelationProperty(
      objectTypeId: weblink.id,
      name: 'Representative Image',
      targetObjectTypeId: image.id,
      multiple: false,
    );

    final source = await DatabaseViewGalleryCoverCompatibilityService(
      objectStore: objectStore,
      systemObjects: systemObjects,
    ).effectiveSource(view: _view(), objectTypeId: weblink.id);

    expect(source, GalleryCoverSource.imageRelation(representative.id));
  });

  test('custom ObjectType remains none until a View chooses a source', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final image = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final bookId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookId,
      name: 'Cover',
      targetObjectTypeId: image.id,
      multiple: false,
    );

    final source = await DatabaseViewGalleryCoverCompatibilityService(
      objectStore: objectStore,
      systemObjects: systemObjects,
    ).effectiveSource(view: _view(), objectTypeId: bookId);

    expect(source, const GalleryCoverSource.none());
  });

  test('persisted explicit none wins over compatibility defaults', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final image = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final view = const DatabaseViewGalleryAdapter().encodeCoverSource(
      _view(),
      source: const GalleryCoverSource.none(),
    );

    final source = await DatabaseViewGalleryCoverCompatibilityService(
      objectStore: objectStore,
      systemObjects: systemObjects,
    ).effectiveSource(view: view, objectTypeId: image.id);

    expect(source, const GalleryCoverSource.none());
  });

  test('malformed persisted setting fails closed instead of using legacy fallback',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final image = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );

    final source = await DatabaseViewGalleryCoverCompatibilityService(
      objectStore: objectStore,
      systemObjects: systemObjects,
    ).effectiveSource(
      view: _view(
        settings: const {
          DatabaseViewGalleryAdapter.coverSourceSettingsKey: 'bad-payload',
        },
      ),
      objectTypeId: image.id,
    );

    expect(source, const GalleryCoverSource.none());
  });
}
