import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'exposed Weblink deletion detaches incoming Bookmark and outgoing Image Relations',
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
      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);

      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES ('https://example.com/article', 'Saved article')",
      );
      final legacyId = (await database.customSelect(
        "SELECT id FROM bookmarks WHERE title = 'Saved article'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        <Object?>[legacyId, workspaceId],
      );
      await sync.syncWorkspace(workspaceId);

      final genericStore = GenericDatabaseStore(database);
      final defaultsStore = ObjectTypeDefaultsStore(genericStore);
      final schema = await WeblinkImageSchemaService(
        systemObjects: sync.systemObjectStore,
        defaultsStore: defaultsStore,
      ).ensureDefinition(workspaceId);
      final imageService = ImageObjectService(
        systemObjects: sync.systemObjectStore,
        defaultsStore: defaultsStore,
      );
      final firstImage = await imageService.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/first.jpg',
        sourceUrl: 'https://cdn.example.com/first.jpg',
      );
      final secondImage = await imageService.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/second.jpg',
        sourceUrl: 'https://cdn.example.com/second.jpg',
      );
      final bidirectionalStore = BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: sync.objectStore,
      );
      final mutations = RelationMutationService(
        objectStore: sync.objectStore,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      );

      final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.bookmarkSystemKey,
      ))!;
      final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ))!;
      final bookmarkRelation = bookmarkType.properties.singleWhere(
        (property) => property.name == 'Weblink',
      );
      final bookmark = (await sync.objectStore.listObjects(bookmarkType.id)).single;
      final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;

      await mutations.setRelation(
        objectId: weblink.id,
        property: schema.representativeImageProperty,
        targetObjectIds: <int>[firstImage.id],
      );
      await mutations.setRelation(
        objectId: weblink.id,
        property: schema.relatedImagesProperty,
        targetObjectIds: <int>[firstImage.id, secondImage.id],
      );

      expect(await sync.objectStore.backlinks(weblink.id), hasLength(1));
      expect(await sync.objectStore.backlinks(firstImage.id), hasLength(2));
      expect(await sync.objectStore.backlinks(secondImage.id), hasLength(1));

      final navigation = await genericStore.listDatabases(workspaceId);
      final destination = navigation.singleWhere(
        (database) => database.id == weblinkType.id,
      );
      expect(destination.name, 'Weblinks');

      tester.view.physicalSize = const Size(1600, 1000);
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
      await tester.pumpAndSettle();

      await tester.tap(find.text(weblink.title).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('削除'));
      await tester.pumpAndSettle();

      expect(await sync.objectStore.listObjects(weblinkType.id), isEmpty);
      final survivingBookmark =
          (await sync.objectStore.listObjects(bookmarkType.id)).single;
      expect(
        ObjectRelationValue.fromJson(
          survivingBookmark.values[bookmarkRelation.id],
        ).objectIds,
        isEmpty,
      );
      expect(await sync.objectStore.outgoingRelations(bookmark.id), isEmpty);
      expect(await sync.objectStore.backlinks(weblink.id), isEmpty);
      expect(await sync.objectStore.outgoingRelations(weblink.id), isEmpty);

      final survivingImages = await sync.objectStore.listObjects(schema.imageObjectTypeId);
      expect(
        survivingImages.map((object) => object.id),
        containsAll(<int>[firstImage.id, secondImage.id]),
      );
      expect(await sync.objectStore.backlinks(firstImage.id), isEmpty);
      expect(await sync.objectStore.backlinks(secondImage.id), isEmpty);

      final integrity = RelationIntegrityService(
        objectStore: sync.objectStore,
        bidirectionalStore: bidirectionalStore,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
