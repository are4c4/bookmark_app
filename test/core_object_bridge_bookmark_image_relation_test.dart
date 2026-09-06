import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy Bookmark photos mirror through one canonical Images Relation lifecycle',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final systemStore = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final tagBridge = TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemStore,
      );
      final bridge = CoreObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemStore,
        tagBridge: tagBridge,
      );

      await database.customStatement(
        "INSERT INTO photos(path, title) VALUES ('photo/first.jpg', 'First image')",
      );
      final photoId = (await database.customSelect(
        "SELECT id FROM photos WHERE path = 'photo/first.jpg'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES ('https://images.example', 'Image bookmark')",
      );
      final bookmarkId = (await database.customSelect(
        "SELECT id FROM bookmarks WHERE url = 'https://images.example'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        [bookmarkId, workspaceId],
      );
      await database.customStatement(
        'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, ?)',
        [bookmarkId, photoId, 1],
      );

      await bridge.syncAll(workspaceId);

      final bookmarkType = (await systemStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.bookmarkSystemKey,
      ))!;
      final imageType = (await systemStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.photoSystemKey,
      ))!;
      final imagesProperty = bookmarkType.properties.singleWhere(
        (property) => property.name == 'Images',
      );
      final bookmarkObjectId = (await database.customSelect(
        'SELECT object_id FROM bookmark_object_links WHERE workspace_id = ? AND bookmark_id = ?',
        variables: [Variable<int>(workspaceId), Variable<int>(bookmarkId)],
      ).getSingle())
          .read<int>('object_id');
      final imageObjectId = (await database.customSelect(
        'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
        variables: [Variable<int>(workspaceId), Variable<int>(photoId)],
      ).getSingle())
          .read<int>('object_id');

      final reads = RelationReadService(objectStore);
      Future<void> expectOneHealthyRelation() async {
        final outgoing = await reads.outgoing(
          sourceObjectTypeId: bookmarkType.id,
          sourceObjectId: bookmarkObjectId,
        );
        final imageRelations = outgoing
            .where((item) => item.property.id == imagesProperty.id)
            .toList(growable: false);
        expect(imageRelations, hasLength(1));
        expect(imageRelations.single.targetObject.id, imageObjectId);

        final edges = (await objectStore.outgoingRelations(bookmarkObjectId))
            .where((edge) => edge.propertyId == imagesProperty.id)
            .toList(growable: false);
        expect(edges, hasLength(1));
        expect(edges.single.targetObjectId, imageObjectId);

        final backlinks = await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: imageObjectId,
        );
        final imageBacklinks = backlinks
            .where(
              (item) =>
                  item.sourceObject.id == bookmarkObjectId &&
                  item.property.id == imagesProperty.id,
            )
            .toList(growable: false);
        expect(imageBacklinks, hasLength(1));

        final integrity = RelationIntegrityService(
          objectStore: objectStore,
          bidirectionalStore: BidirectionalRelationStore(
            genericStore: genericStore,
            objectStore: objectStore,
          ),
        );
        expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
      }

      await expectOneHealthyRelation();

      // Re-running compatibility sync must not duplicate the Relation/index/backlink.
      await bridge.syncAll(workspaceId);
      await expectOneHealthyRelation();

      // Removing the legacy attachment detaches the canonical multi-Relation.
      await database.customStatement(
        'DELETE FROM bookmark_photos WHERE bookmark_id = ? AND photo_id = ?',
        [bookmarkId, photoId],
      );
      await bridge.syncAll(workspaceId);

      final detachedOutgoing = await reads.outgoing(
        sourceObjectTypeId: bookmarkType.id,
        sourceObjectId: bookmarkObjectId,
      );
      expect(
        detachedOutgoing.where((item) => item.property.id == imagesProperty.id),
        isEmpty,
      );
      expect(
        (await objectStore.outgoingRelations(bookmarkObjectId))
            .where((edge) => edge.propertyId == imagesProperty.id),
        isEmpty,
      );
      expect(
        (await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: imageObjectId,
        )).where(
          (item) =>
              item.sourceObject.id == bookmarkObjectId &&
              item.property.id == imagesProperty.id,
        ),
        isEmpty,
      );

      final integrity = RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
      expect((await objectStore.listObjects(imageType.id)).single.id, imageObjectId);
    },
  );
}
