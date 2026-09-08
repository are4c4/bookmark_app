import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
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
    'legacy Image deletion detaches Bookmark Relations and backlinks',
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
      final bridge = CoreObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemStore,
        tagBridge: TagObjectBridge(
          database: database,
          objectStore: objectStore,
          systemObjectStore: systemStore,
        ),
      );
      final pageServices = GenericDatabasePageServices.fromStores(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final reads = RelationReadService(objectStore);
      final integrity = RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
      );

      await database.customStatement(
        "INSERT INTO photos(path, title) VALUES ('photo/guard.jpg', 'Guard image')",
      );
      final photoId = (await database.customSelect(
        "SELECT id FROM photos WHERE path = 'photo/guard.jpg'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES ('https://guard.example', 'Guard bookmark')",
      );
      final bookmarkId = (await database.customSelect(
        "SELECT id FROM bookmarks WHERE url = 'https://guard.example'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        <Object>[bookmarkId, workspaceId],
      );
      await database.customStatement(
        'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
        <Object>[bookmarkId, photoId],
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
      final coverProperty = bookmarkType.properties.singleWhere(
        (property) => property.name == 'Cover Image',
      );
      final bookmarkObjectId = (await database.customSelect(
        'SELECT object_id FROM bookmark_object_links '
        'WHERE workspace_id = ? AND bookmark_id = ?',
        variables: [Variable<int>(workspaceId), Variable<int>(bookmarkId)],
      ).getSingle())
          .read<int>('object_id');
      final imageObjectId = (await database.customSelect(
        'SELECT object_id FROM photo_object_links '
        'WHERE workspace_id = ? AND photo_id = ?',
        variables: [Variable<int>(workspaceId), Variable<int>(photoId)],
      ).getSingle())
          .read<int>('object_id');

      Future<void> expectRelationsPreserved() async {
        final outgoing = await reads.outgoing(
          sourceObjectTypeId: bookmarkType.id,
          sourceObjectId: bookmarkObjectId,
        );
        final imageRelations = outgoing
            .where(
              (item) =>
                  item.property.id == imagesProperty.id ||
                  item.property.id == coverProperty.id,
            )
            .toList(growable: false);
        expect(imageRelations, hasLength(2));
        expect(
          imageRelations.map((item) => item.property.id).toSet(),
          <int>{imagesProperty.id, coverProperty.id},
        );
        expect(
          imageRelations.map((item) => item.targetObject.id).toSet(),
          <int>{imageObjectId},
        );

        final edges = await objectStore.outgoingRelations(bookmarkObjectId);
        final imageEdges = edges
            .where(
              (edge) =>
                  edge.propertyId == imagesProperty.id ||
                  edge.propertyId == coverProperty.id,
            )
            .toList(growable: false);
        expect(imageEdges, hasLength(2));
        expect(
          imageEdges.map((edge) => edge.propertyId).toSet(),
          <int>{imagesProperty.id, coverProperty.id},
        );
        expect(
          imageEdges.map((edge) => edge.targetObjectId).toSet(),
          <int>{imageObjectId},
        );

        final backlinks = await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: imageObjectId,
        );
        final bookmarkBacklinks = backlinks
            .where((item) => item.sourceObject.id == bookmarkObjectId)
            .toList(growable: false);
        expect(bookmarkBacklinks, hasLength(2));
        expect(
          bookmarkBacklinks.map((item) => item.property.id).toSet(),
          <int>{imagesProperty.id, coverProperty.id},
        );
        expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
      }

      await expectRelationsPreserved();

      await pageServices.relationMutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: imageType.id,
        objectId: imageObjectId,
      );

      expect(
        (await objectStore.listObjects(imageType.id)).map((object) => object.id),
        isNot(contains(imageObjectId)),
      );
      expect(
        await database.customSelect(
          'SELECT id FROM photos WHERE id = $photoId',
        ).get(),
        isEmpty,
      );
      final outgoingAfterDelete = await reads.outgoing(
        sourceObjectTypeId: bookmarkType.id,
        sourceObjectId: bookmarkObjectId,
      );
      expect(
        outgoingAfterDelete.where(
          (item) =>
              item.property.id == imagesProperty.id ||
              item.property.id == coverProperty.id,
        ),
        isEmpty,
      );
      expect(
        await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: imageObjectId,
        ),
        isEmpty,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
