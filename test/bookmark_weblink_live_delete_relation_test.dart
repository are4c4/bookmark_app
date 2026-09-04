import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'canonical Weblink deletion detaches live mirrored Bookmark Relation',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);

      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES ('https://example.com/delete-me', 'Bookmark')",
      );
      final legacyBookmarkId = (await database.customSelect(
        "SELECT id FROM bookmarks WHERE title = 'Bookmark' LIMIT 1",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        <Object>[legacyBookmarkId, workspaceId],
      );

      await sync.syncWorkspace(workspaceId);

      final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.bookmarkSystemKey,
      ))!;
      final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ))!;
      final relation = bookmarkType.properties.singleWhere(
        (property) => property.name == 'Weblink',
      );
      final bookmark = (await sync.objectStore.listObjects(bookmarkType.id)).single;
      final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
      expect(
        ObjectRelationValue.fromJson(bookmark.values[relation.id]).objectIds,
        <int>[weblink.id],
      );

      final genericStore = GenericDatabaseStore(database);
      final bidirectionalStore = BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: sync.objectStore,
      );
      final mutations = RelationMutationService(
        objectStore: sync.objectStore,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      );
      final reads = RelationReadService(sync.objectStore);
      expect(
        (await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: weblink.id,
        )).map((item) => item.sourceObject.id),
        <int>[bookmark.id],
      );

      await mutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: weblinkType.id,
        objectId: weblink.id,
      );

      expect(await sync.objectStore.listObjects(weblinkType.id), isEmpty);
      final survivingBookmark =
          (await sync.objectStore.listObjects(bookmarkType.id)).single;
      expect(survivingBookmark.id, bookmark.id);
      expect(
        ObjectRelationValue.fromJson(
          survivingBookmark.values[relation.id],
        ).objectIds,
        isEmpty,
      );
      expect(
        (await sync.objectStore.outgoingRelations(survivingBookmark.id))
            .where((edge) => edge.propertyId == relation.id),
        isEmpty,
      );
      expect(await sync.objectStore.backlinks(weblink.id), isEmpty);
      expect(
        await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: weblink.id,
        ),
        isEmpty,
      );

      final integrity = RelationIntegrityService(
        objectStore: sync.objectStore,
        bidirectionalStore: bidirectionalStore,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
