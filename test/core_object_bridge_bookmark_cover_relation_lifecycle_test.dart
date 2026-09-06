import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Bookmark Cover Image mirror keeps canonical Relation lifecycle healthy',
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
      final bidirectionalStore = BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final mutations = RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      );
      final reads = RelationReadService(objectStore);
      final integrity = RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
      );

      await database.customStatement(
        "INSERT INTO photos(path, title) VALUES ('photo/a.jpg', 'A')",
      );
      await database.customStatement(
        "INSERT INTO photos(path, title) VALUES ('photo/b.jpg', 'B')",
      );
      final photoRows = await database.customSelect(
        "SELECT id, path FROM photos WHERE path IN ('photo/a.jpg', 'photo/b.jpg') ORDER BY path",
      ).get();
      final photoAId = photoRows[0].read<int>('id');
      final photoBId = photoRows[1].read<int>('id');

      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES ('https://cover.example', 'Cover bookmark')",
      );
      final bookmarkId = (await database.customSelect(
        "SELECT id FROM bookmarks WHERE url = 'https://cover.example'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        <Object>[bookmarkId, workspaceId],
      );
      await database.customStatement(
        'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
        <Object>[bookmarkId, photoAId],
      );
      await database.customStatement(
        'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 0)',
        <Object>[bookmarkId, photoBId],
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
      expect(coverProperty.isRelation, isTrue);
      expect(coverProperty.targetObjectTypeId, imageType.id);
      expect(coverProperty.allowsMultipleRelations, isFalse);

      final bookmarkObjectId = (await database.customSelect(
        'SELECT object_id FROM bookmark_object_links WHERE workspace_id = ? AND bookmark_id = ?',
        variables: <Variable<Object>>[
          Variable<int>(workspaceId),
          Variable<int>(bookmarkId),
        ],
      ).getSingle())
          .read<int>('object_id');
      final imageAId = (await database.customSelect(
        'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
        variables: <Variable<Object>>[
          Variable<int>(workspaceId),
          Variable<int>(photoAId),
        ],
      ).getSingle())
          .read<int>('object_id');
      final imageBId = (await database.customSelect(
        'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
        variables: <Variable<Object>>[
          Variable<int>(workspaceId),
          Variable<int>(photoBId),
        ],
      ).getSingle())
          .read<int>('object_id');

      Future<void> expectHealthyState({required int coverImageId}) async {
        final outgoing = await reads.outgoing(
          sourceObjectTypeId: bookmarkType.id,
          sourceObjectId: bookmarkObjectId,
        );
        final coverRelations = outgoing
            .where((item) => item.property.id == coverProperty.id)
            .toList(growable: false);
        expect(coverRelations, hasLength(1));
        expect(coverRelations.single.targetObject.id, coverImageId);

        final imageRelations = outgoing
            .where((item) => item.property.id == imagesProperty.id)
            .toList(growable: false);
        expect(
          imageRelations.map((item) => item.targetObject.id).toSet(),
          <int>{imageAId, imageBId},
        );

        final edges = await objectStore.outgoingRelations(bookmarkObjectId);
        expect(
          edges
              .where((edge) => edge.propertyId == coverProperty.id)
              .map((edge) => edge.targetObjectId)
              .toList(growable: false),
          <int>[coverImageId],
        );
        expect(
          edges
              .where((edge) => edge.propertyId == imagesProperty.id)
              .map((edge) => edge.targetObjectId)
              .toSet(),
          <int>{imageAId, imageBId},
        );

        final coverBacklinks = await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: coverImageId,
        );
        expect(
          coverBacklinks.where(
            (item) =>
                item.sourceObject.id == bookmarkObjectId &&
                item.property.id == coverProperty.id,
          ),
          hasLength(1),
        );
        expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
      }

      await expectHealthyState(coverImageId: imageAId);

      // Retrying the compatibility sync must not duplicate either Relation or edge.
      await bridge.syncAll(workspaceId);
      await expectHealthyState(coverImageId: imageAId);

      // Retarget the single cover while preserving the multi Images Relation.
      await database.customStatement(
        'UPDATE bookmark_photos SET is_cover = 0 WHERE bookmark_id = ?',
        <Object>[bookmarkId],
      );
      await database.customStatement(
        'UPDATE bookmark_photos SET is_cover = 1 WHERE bookmark_id = ? AND photo_id = ?',
        <Object>[bookmarkId, photoBId],
      );
      await bridge.syncAll(workspaceId);
      await expectHealthyState(coverImageId: imageBId);

      final oldCoverBacklinks = await reads.backlinks(
        workspaceId: workspaceId,
        targetObjectId: imageAId,
      );
      expect(
        oldCoverBacklinks.where(
          (item) =>
              item.sourceObject.id == bookmarkObjectId &&
              item.property.id == coverProperty.id,
        ),
        isEmpty,
      );

      // Relation-safe Image deletion must detach both Cover Image and Images.
      await mutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: imageType.id,
        objectId: imageBId,
      );

      final afterDelete = await reads.outgoing(
        sourceObjectTypeId: bookmarkType.id,
        sourceObjectId: bookmarkObjectId,
      );
      expect(
        afterDelete.where((item) => item.property.id == coverProperty.id),
        isEmpty,
      );
      expect(
        afterDelete
            .where((item) => item.property.id == imagesProperty.id)
            .map((item) => item.targetObject.id)
            .toList(growable: false),
        <int>[imageAId],
      );
      expect(await objectStore.backlinks(imageBId), isEmpty);
      expect(
        await reads.backlinks(
          workspaceId: workspaceId,
          targetObjectId: imageBId,
        ),
        isEmpty,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
