import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/database/presentation/widgets/image_gallery_media.dart';
import 'package:bookmark_app/features/database/presentation/widgets/weblink_gallery_media.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('generic system Gallery media delegates Image Objects to Image media',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final imageService = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await imageService.ensureDefinition(workspaceId);
    final image = await imageService.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/example.png',
      originalFilename: 'example.png',
      pixelWidth: 1200,
      pixelHeight: 800,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: WeblinkGalleryMedia(
              database: database,
              objectStore: objectStore,
              workspaceId: workspaceId,
              objectTypeId: definition.objectType.id,
              objectId: image.id,
              mode: GalleryViewMode.masonry,
            ),
          ),
        ),
      ),
    );

    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byType(ImageGalleryMedia).evaluate().isNotEmpty) break;
    }

    expect(find.byType(ImageGalleryMedia), findsOneWidget);
    final media = tester.widget<ImageGalleryMedia>(find.byType(ImageGalleryMedia));
    expect(media.objectTypeId, definition.objectType.id);
    expect(media.objectId, image.id);
    expect(media.mode, GalleryViewMode.masonry);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
