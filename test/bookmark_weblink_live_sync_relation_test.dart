import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'live Bookmark Weblink sync retargets and detaches without stale edges',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);

      const firstUrl = 'https://example.com/first';
      const secondUrl = 'https://example.com/second';
      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES (?, 'Bookmark')",
        <Object>[firstUrl],
      );
      final legacyBookmarkId = (await database.customSelect(
        'SELECT id FROM bookmarks WHERE url = ? LIMIT 1',
        variables: [Variable<String>(firstUrl)],
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
      final urlProperty = weblinkType.properties.singleWhere(
        (property) => property.name == 'URL',
      );
      final bookmark = (await sync.objectStore.listObjects(bookmarkType.id)).single;
      final firstWeblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
      expect(
        ObjectRelationValue.fromJson(bookmark.values[relation.id]).objectIds,
        <int>[firstWeblink.id],
      );

      final reads = RelationReadService(sync.objectStore);
      expect(
        (await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: firstWeblink.id,
        )).map((item) => item.sourceObject.id),
        <int>[bookmark.id],
      );

      await database.customStatement(
        'UPDATE bookmarks SET url = ? WHERE id = ?',
        <Object>[secondUrl, legacyBookmarkId],
      );
      await sync.syncWorkspace(workspaceId);

      final weblinksAfterRetarget = await sync.objectStore.listObjects(weblinkType.id);
      final oldTarget = weblinksAfterRetarget.singleWhere(
        (object) => object.values[urlProperty.id] == firstUrl,
      );
      final newTarget = weblinksAfterRetarget.singleWhere(
        (object) => object.values[urlProperty.id] == secondUrl,
      );
      final bookmarkAfterRetarget =
          (await sync.objectStore.listObjects(bookmarkType.id)).single;
      expect(
        ObjectRelationValue.fromJson(
          bookmarkAfterRetarget.values[relation.id],
        ).objectIds,
        <int>[newTarget.id],
      );

      final relationEdges = (await sync.objectStore.outgoingRelations(
        bookmarkAfterRetarget.id,
      ))
          .where((edge) => edge.propertyId == relation.id)
          .toList(growable: false);
      expect(relationEdges, hasLength(1));
      expect(relationEdges.single.targetObjectId, newTarget.id);
      expect(await sync.objectStore.backlinks(oldTarget.id), isEmpty);
      expect(
        (await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: newTarget.id,
        )).map((item) => item.sourceObject.id),
        <int>[bookmark.id],
      );

      final genericStore = GenericDatabaseStore(database);
      final integrity = RelationIntegrityService(
        objectStore: sync.objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: sync.objectStore,
        ),
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);

      await database.customStatement(
        'UPDATE bookmarks SET url = ? WHERE id = ?',
        <Object>['not a valid absolute url', legacyBookmarkId],
      );
      await sync.syncWorkspace(workspaceId);

      final bookmarkAfterInvalidUrl =
          (await sync.objectStore.listObjects(bookmarkType.id)).single;
      expect(
        ObjectRelationValue.fromJson(
          bookmarkAfterInvalidUrl.values[relation.id],
        ).objectIds,
        isEmpty,
      );
      expect(
        (await sync.objectStore.outgoingRelations(bookmarkAfterInvalidUrl.id))
            .where((edge) => edge.propertyId == relation.id),
        isEmpty,
      );
      expect(await sync.objectStore.backlinks(newTarget.id), isEmpty);
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
