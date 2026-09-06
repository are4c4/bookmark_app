import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mirrored Bookmark image usage is visible as canonical Image backlinks',
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
      final bridge = CoreObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
        tagBridge: TagObjectBridge(
          database: database,
          objectStore: objectStore,
          systemObjectStore: systemObjects,
        ),
      );

      await database.customStatement(
        "INSERT INTO photos(path, title, note) VALUES ('photo/cover.jpg', 'Cover photo', 'Legacy note')",
      );
      final photoId = (await database.customSelect(
        "SELECT id FROM photos WHERE path = 'photo/cover.jpg'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        "INSERT INTO bookmarks(url, title, description) VALUES ('https://example.com/article', 'Bookmark using image', 'Description')",
      );
      final bookmarkId = (await database.customSelect(
        "SELECT id FROM bookmarks WHERE url = 'https://example.com/article'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        [bookmarkId, workspaceId],
      );
      await database.customStatement(
        'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
        [bookmarkId, photoId],
      );

      await bridge.syncAll(workspaceId);

      final imageType = (await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.photoSystemKey,
      ))!;
      final image = (await objectStore.listObjects(imageType.id)).single;
      final neighborhood = await RelationReadService(objectStore).neighborhood(
        workspaceId: workspaceId,
        objectTypeId: imageType.id,
        objectId: image.id,
      );
      expect(neighborhood.backlinks, hasLength(2));
      expect(
        neighborhood.backlinks.map((backlink) => backlink.property.name).toSet(),
        <String>{'Images', 'Cover Image'},
      );
      expect(
        neighborhood.backlinks
            .map((backlink) => backlink.sourceObject.title)
            .toList(growable: false),
        everyElement('Bookmark using image'),
      );

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: GenericDatabasePage(
            repository: repository,
            databaseId: imageType.id,
            onDatabaseChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(image.title).first);
      await tester.pumpAndSettle();

      expect(find.text('Backlinks  2'), findsOneWidget);
      expect(find.text('Bookmark using image'), findsNWidgets(2));
    },
  );
}
