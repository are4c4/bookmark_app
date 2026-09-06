import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/database/presentation/widgets/image_gallery_media.dart';
import 'package:bookmark_app/widgets/database_gallery_view_cover_media.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
  late AppDatabase database;
  late int workspaceId;
  late ObjectStore objectStore;
  late SystemObjectStore systemObjects;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    objectStore = ObjectStore(GenericDatabaseStore(database));
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Widget host({
    required DatabaseViewConfig view,
    required int sourceObjectTypeId,
    required int sourceObjectId,
    GalleryViewMode mode = GalleryViewMode.fixed,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: DatabaseGalleryViewCoverMedia(
              database: database,
              objectStore: objectStore,
              workspaceId: workspaceId,
              view: view,
              sourceObjectTypeId: sourceObjectTypeId,
              sourceObjectId: sourceObjectId,
              mode: mode,
            ),
          ),
        ),
      );

  testWidgets('unconfigured custom View stays media-free', (tester) async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Book A',
    );

    await tester.pumpWidget(
      host(
        view: _view(),
        sourceObjectTypeId: typeId,
        sourceObjectId: objectId,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('database-gallery-cover-none')),
      findsOneWidget,
    );
    expect(find.byType(ImageGalleryMedia), findsNothing);
  });

  testWidgets('unconfigured system Image preserves direct media compatibility',
      (tester) async {
    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final imageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Image A',
    );

    await tester.pumpWidget(
      host(
        view: _view(),
        sourceObjectTypeId: imageType.id,
        sourceObjectId: imageId,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ImageGalleryMedia), findsOneWidget);
    final media = tester.widget<ImageGalleryMedia>(find.byType(ImageGalleryMedia));
    expect(media.objectTypeId, imageType.id);
    expect(media.objectId, imageId);
  });

  testWidgets('persisted custom Image Relation dispatches through configured cover',
      (tester) async {
    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Paper',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: typeId,
      name: 'Cover',
      targetObjectTypeId: imageType.id,
      multiple: false,
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Paper A',
    );
    final imageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Cover',
    );
    final property = (await objectStore.getObjectType(typeId))!
        .properties
        .singleWhere((property) => property.id == relationId);
    await objectStore.setRelation(
      objectId: sourceId,
      property: property,
      targetObjectIds: [imageId],
    );
    final view = const DatabaseViewGalleryAdapter().encodeCoverSource(
      _view(),
      source: GalleryCoverSource.imageRelation(relationId),
    );

    await tester.pumpWidget(
      host(
        view: view,
        sourceObjectTypeId: typeId,
        sourceObjectId: sourceId,
        mode: GalleryViewMode.masonry,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ImageGalleryMedia), findsOneWidget);
    final media = tester.widget<ImageGalleryMedia>(find.byType(ImageGalleryMedia));
    expect(media.objectId, imageId);
    expect(media.mode, GalleryViewMode.masonry);
  });

  testWidgets('persisted explicit none overrides system compatibility',
      (tester) async {
    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final imageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Image A',
    );
    final view = const DatabaseViewGalleryAdapter().encodeCoverSource(
      _view(),
      source: const GalleryCoverSource.none(),
    );

    await tester.pumpWidget(
      host(
        view: view,
        sourceObjectTypeId: imageType.id,
        sourceObjectId: imageId,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('database-gallery-cover-none')),
      findsOneWidget,
    );
    expect(find.byType(ImageGalleryMedia), findsNothing);
  });
}
