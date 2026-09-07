import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/database/presentation/widgets/object_gallery_view.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'real Images host seeds Gallery once and preserves later View customization',
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
      final images = ImageObjectService(
        systemObjects: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );
      final imageDefinition = await images.ensureDefinition(workspaceId);
      await objectStore.createObject(
        objectTypeId: imageDefinition.objectType.id,
        title: 'First canonical Image',
      );
      final destination = (await genericStore.listDatabases(workspaceId))
          .singleWhere((item) => item.id == imageDefinition.objectType.id);
      final viewStore = DatabaseViewStore(database);
      final databaseKey = destination.databaseKey;

      expect(
        await viewStore.listViews(
          workspaceId: workspaceId,
          databaseKey: databaseKey,
        ),
        isEmpty,
      );

      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pumpHost() => tester.pumpWidget(
            MaterialApp(
              home: GenericDatabasePage(
                repository: repository,
                databaseId: destination.id,
                onDatabaseChanged: () {},
              ),
            ),
          );

      Future<List<DatabaseViewConfig>> waitForViews() async {
        for (var attempt = 0; attempt < 40; attempt += 1) {
          await tester.pump(const Duration(milliseconds: 50));
          final views = await viewStore.listViews(
            workspaceId: workspaceId,
            databaseKey: databaseKey,
          );
          if (views.isNotEmpty) return views;
        }
        return viewStore.listViews(
          workspaceId: workspaceId,
          databaseKey: databaseKey,
        );
      }

      Future<void> pumpUntilVisible(Finder finder) async {
        if (finder.evaluate().isNotEmpty) return;
        for (var attempt = 0; attempt < 40; attempt += 1) {
          await tester.pump(const Duration(milliseconds: 50));
          if (finder.evaluate().isNotEmpty) return;
        }
        expect(finder, findsWidgets);
      }

      await pumpHost();
      final seededViews = await waitForViews();
      expect(seededViews, hasLength(1));
      final seeded = seededViews.single;
      expect(seeded.name, 'ギャラリー');
      expect(seeded.layoutType, 'gallery');
      expect(
        const DatabaseViewGalleryAdapter().decode(seeded),
        GalleryViewMode.masonry,
      );
      expect(
        const DatabaseViewGalleryAdapter().decodeCoverSource(seeded),
        const GalleryCoverSource.directImage(),
      );

      await pumpUntilVisible(find.byType(ObjectGalleryView));
      expect(find.byType(ObjectGalleryView), findsOneWidget);
      expect(find.text('ギャラリー'), findsWidgets);
      expect(find.text('カバー: このImage'), findsOneWidget);

      final customized = seeded.copyWith(
        name: 'My Images',
        layoutType: 'list',
        settings: const <String, dynamic>{'userCustomized': true},
      );
      await viewStore.updateView(customized);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpHost();
      await pumpUntilVisible(find.text('My Images'));

      final reopenedViews = await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: databaseKey,
      );
      expect(reopenedViews, hasLength(1));
      final reopened = reopenedViews.single;
      expect(reopened.id, seeded.id);
      expect(reopened.name, 'My Images');
      expect(reopened.layoutType, 'list');
      expect(
        reopened.settings,
        const <String, dynamic>{'userCustomized': true},
      );
      expect(find.byType(ObjectGalleryView), findsNothing);
    },
  );
}
