import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/database/presentation/widgets/database_gallery_cover_media.dart';
import 'package:bookmark_app/features/database/presentation/widgets/image_gallery_media.dart';
import 'package:bookmark_app/features/database/presentation/widgets/weblink_gallery_media.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    required int sourceObjectTypeId,
    required int sourceObjectId,
    required GalleryCoverSource source,
    GalleryViewMode mode = GalleryViewMode.fixed,
  }) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: DatabaseGalleryCoverMedia(
              database: database,
              objectStore: objectStore,
              workspaceId: workspaceId,
              sourceObjectTypeId: sourceObjectTypeId,
              sourceObjectId: sourceObjectId,
              source: source,
              mode: mode,
            ),
          ),
        ),
      );

  testWidgets('explicit none removes Gallery media geometry', (tester) async {
    await tester.pumpWidget(
      host(
        sourceObjectTypeId: 1,
        sourceObjectId: 1,
        source: const GalleryCoverSource.none(),
      ),
    );

    expect(find.byKey(const ValueKey('database-gallery-cover-none')), findsOneWidget);
    expect(find.byType(ImageGalleryMedia), findsNothing);
    expect(find.byType(WeblinkGalleryMedia), findsNothing);
  });

  testWidgets('unresolvable configured source keeps stable fixed geometry',
      (tester) async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book A',
    );

    await tester.pumpWidget(
      host(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: sourceId,
        source: const GalleryCoverSource.imageRelation(999),
      ),
    );
    await tester.pumpAndSettle();

    final fallback = find.byKey(
      ValueKey('database-gallery-cover-fallback-fixed-$sourceId'),
    );
    expect(fallback, findsOneWidget);
    expect(tester.getSize(fallback).height, 96);
  });

  testWidgets('unresolvable configured source keeps stable masonry fallback',
      (tester) async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Paper',
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Paper A',
    );

    await tester.pumpWidget(
      host(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: sourceId,
        source: const GalleryCoverSource.imageRelation(999),
        mode: GalleryViewMode.masonry,
      ),
    );
    await tester.pumpAndSettle();

    final fallback = find.byKey(
      ValueKey('database-gallery-cover-fallback-masonry-$sourceId'),
    );
    expect(fallback, findsOneWidget);
    expect(tester.getSize(fallback).height, 160);
  });

  testWidgets('direct Image source dispatches to canonical Image media',
      (tester) async {
    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final imageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Cover',
    );

    await tester.pumpWidget(
      host(
        sourceObjectTypeId: imageType.id,
        sourceObjectId: imageId,
        source: const GalleryCoverSource.directImage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ImageGalleryMedia), findsOneWidget);
    expect(find.byType(WeblinkGalleryMedia), findsNothing);
    expect(
      find.byKey(ValueKey('image-gallery-media-fixed-$imageId')),
      findsOneWidget,
    );
  });

  testWidgets('Weblink Relation dispatches to canonical Weblink media',
      (tester) async {
    final weblinkType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
      name: 'Weblink',
      icon: '🔗',
    );
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Recipe',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Source',
      targetObjectTypeId: weblinkType.id,
      multiple: false,
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Recipe A',
    );
    final weblinkId = await objectStore.createObject(
      objectTypeId: weblinkType.id,
      title: 'Reference',
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .firstWhere((candidate) => candidate.id == relationId);
    await objectStore.setRelation(
      objectId: sourceId,
      property: property,
      targetObjectIds: [weblinkId],
    );

    await tester.pumpWidget(
      host(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: sourceId,
        source: GalleryCoverSource.weblinkRelationRepresentativeImage(relationId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeblinkGalleryMedia), findsOneWidget);
    expect(find.byType(ImageGalleryMedia), findsNothing);
  });
}
