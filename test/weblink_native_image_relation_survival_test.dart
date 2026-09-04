import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native Image used by Weblink Relation survives compatibility sync',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);

      await sync.syncWorkspace(workspaceId);
      final imageType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.photoSystemKey,
      ))!;
      final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ))!;
      final representative = await sync.systemObjectStore.ensureRelationProperty(
        objectTypeId: weblinkType.id,
        name: 'Representative image',
        targetObjectTypeId: imageType.id,
        multiple: false,
      );
      final nativeImageId = await sync.objectStore.createObject(
        objectTypeId: imageType.id,
        title: 'Native image',
      );
      final weblinkId = await sync.objectStore.createObject(
        objectTypeId: weblinkType.id,
        title: 'Weblink',
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
      await mutations.setRelation(
        objectId: weblinkId,
        property: representative,
        targetObjectIds: <int>[nativeImageId],
      );

      await sync.coreBridge.syncAll(workspaceId);

      expect(
        (await sync.objectStore.listObjects(imageType.id)).map((object) => object.id),
        contains(nativeImageId),
      );
      final weblink = (await sync.objectStore.listObjects(weblinkType.id))
          .singleWhere((object) => object.id == weblinkId);
      expect(
        ObjectRelationValue.fromJson(weblink.values[representative.id]).objectIds,
        <int>[nativeImageId],
      );
      final edges = (await sync.objectStore.outgoingRelations(weblinkId))
          .where((edge) => edge.propertyId == representative.id)
          .toList(growable: false);
      expect(edges, hasLength(1));
      expect(edges.single.targetObjectId, nativeImageId);
      expect(await sync.objectStore.backlinks(nativeImageId), hasLength(1));

      final integrity = RelationIntegrityService(
        objectStore: sync.objectStore,
        bidirectionalStore: bidirectionalStore,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );

  test(
    'stale mirrored Image deletion preserves native target in multi Relation',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);

      await database.customStatement(
        "INSERT INTO photos(path, title) VALUES ('legacy.jpg', 'Legacy image')",
      );
      final legacyPhotoId = (await database.customSelect(
        "SELECT id FROM photos WHERE path = 'legacy.jpg' LIMIT 1",
      ).getSingle())
          .read<int>('id');
      await sync.syncWorkspace(workspaceId);

      final imageType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.photoSystemKey,
      ))!;
      final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ))!;
      final relatedImages = await sync.systemObjectStore.ensureRelationProperty(
        objectTypeId: weblinkType.id,
        name: 'Related images',
        targetObjectTypeId: imageType.id,
        multiple: true,
      );
      final legacyIdProperty = imageType.properties.singleWhere(
        (property) => property.name == 'Legacy Photo ID',
      );
      final mirroredImage = (await sync.objectStore.listObjects(imageType.id))
          .singleWhere(
            (object) => object.values[legacyIdProperty.id] == legacyPhotoId,
          );
      final nativeImageId = await sync.objectStore.createObject(
        objectTypeId: imageType.id,
        title: 'Native image',
      );
      final weblinkId = await sync.objectStore.createObject(
        objectTypeId: weblinkType.id,
        title: 'Weblink',
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
      await mutations.setRelation(
        objectId: weblinkId,
        property: relatedImages,
        targetObjectIds: <int>[mirroredImage.id, nativeImageId],
      );

      await database.customStatement(
        'DELETE FROM photos WHERE id = ?',
        <Object>[legacyPhotoId],
      );
      await sync.coreBridge.syncAll(workspaceId);

      final imageIds =
          (await sync.objectStore.listObjects(imageType.id)).map((object) => object.id);
      expect(imageIds, isNot(contains(mirroredImage.id)));
      expect(imageIds, contains(nativeImageId));

      final weblink = (await sync.objectStore.listObjects(weblinkType.id))
          .singleWhere((object) => object.id == weblinkId);
      expect(
        ObjectRelationValue.fromJson(weblink.values[relatedImages.id]).objectIds,
        <int>[nativeImageId],
      );
      final edges = (await sync.objectStore.outgoingRelations(weblinkId))
          .where((edge) => edge.propertyId == relatedImages.id)
          .toList(growable: false);
      expect(edges, hasLength(1));
      expect(edges.single.targetObjectId, nativeImageId);
      expect(await sync.objectStore.backlinks(mirroredImage.id), isEmpty);
      expect(await sync.objectStore.backlinks(nativeImageId), hasLength(1));

      final integrity = RelationIntegrityService(
        objectStore: sync.objectStore,
        bidirectionalStore: bidirectionalStore,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
