import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/relation_index_reconcile_service.dart';
import 'package:bookmark_app/data/relation_index_service.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'live shared Weblink deletion detaches every surviving Bookmark',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);

      const url = 'https://example.com/shared-delete';
      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES (?, 'First')",
        <Object>[url],
      );
      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES (?, 'Second')",
        <Object>[url],
      );
      final legacyRows = await database.customSelect(
        'SELECT id FROM bookmarks WHERE url = ? ORDER BY id',
        variables: [Variable<String>(url)],
      ).get();
      for (final row in legacyRows) {
        await database.customStatement(
          'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
          <Object>[row.read<int>('id'), workspaceId],
        );
      }

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
      final bookmarks = await sync.objectStore.listObjects(bookmarkType.id);
      final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
      expect(bookmarks, hasLength(2));
      expect(await sync.objectStore.backlinks(weblink.id), hasLength(2));

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

      await mutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: weblinkType.id,
        objectId: weblink.id,
      );

      expect(await sync.objectStore.listObjects(weblinkType.id), isEmpty);
      final survivingBookmarks = await sync.objectStore.listObjects(bookmarkType.id);
      expect(survivingBookmarks, hasLength(2));
      for (final bookmark in survivingBookmarks) {
        expect(
          ObjectRelationValue.fromJson(bookmark.values[relation.id]).objectIds,
          isEmpty,
        );
        expect(
          (await sync.objectStore.outgoingRelations(bookmark.id))
              .where((edge) => edge.propertyId == relation.id),
          isEmpty,
        );
      }
      expect(await sync.objectStore.backlinks(weblink.id), isEmpty);

      final integrity = RelationIntegrityService(
        objectStore: sync.objectStore,
        bidirectionalStore: bidirectionalStore,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );

  test(
    'live Bookmark Weblink index-only drift reconciles from persisted Relation',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);

      const url = 'https://example.com/reconcile-live';
      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES (?, 'Bookmark')",
        <Object>[url],
      );
      final legacyBookmarkId = (await database.customSelect(
        'SELECT id FROM bookmarks WHERE url = ? LIMIT 1',
        variables: [Variable<String>(url)],
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
      final directUrl = bookmarkType.properties.singleWhere(
        (property) => property.name == 'URL',
      );
      final bookmark = (await sync.objectStore.listObjects(bookmarkType.id)).single;
      final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
      final persistedBefore = ObjectRelationValue.fromJson(
        bookmark.values[relation.id],
      ).objectIds;
      expect(persistedBefore, <int>[weblink.id]);
      expect(bookmark.values[directUrl.id], isNull);

      await database.customStatement(
        'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
        <Object>[bookmark.id, relation.id],
      );
      expect(
        (await sync.objectStore.outgoingRelations(bookmark.id))
            .where((edge) => edge.propertyId == relation.id),
        isEmpty,
      );

      final genericStore = GenericDatabaseStore(database);
      final bidirectionalStore = BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: sync.objectStore,
      );
      final integrity = RelationIntegrityService(
        objectStore: sync.objectStore,
        bidirectionalStore: bidirectionalStore,
      );
      final before = await integrity.auditWorkspace(workspaceId);
      expect(
        before.issuesOf(RelationIntegrityIssueKind.missingIndexEdge),
        hasLength(1),
      );

      final reconcile = RelationIndexReconcileService(
        integrityService: integrity,
        indexService: RelationIndexService(sync.objectStore),
      );
      final result = await reconcile.reconcileWorkspace(workspaceId);

      expect(result.rebuilt, isTrue);
      expect(result.after.isHealthy, isTrue);
      final refreshed = (await sync.objectStore.listObjects(bookmarkType.id)).single;
      expect(
        ObjectRelationValue.fromJson(refreshed.values[relation.id]).objectIds,
        persistedBefore,
      );
      expect(refreshed.values[directUrl.id], isNull);
      final edges = (await sync.objectStore.outgoingRelations(refreshed.id))
          .where((edge) => edge.propertyId == relation.id)
          .toList(growable: false);
      expect(edges, hasLength(1));
      expect(edges.single.targetObjectId, weblink.id);
    },
  );
}
