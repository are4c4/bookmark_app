import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real page services create canonical Weblink/Image targets and attach Relations',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final services = GenericDatabasePageServices.fromStores(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final schema = await WeblinkImageSchemaService(
        systemObjects: systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      ).ensureDefinition(workspaceId);

      final weblinkId = await services.creator.createWeblinkFromUrl(
        databaseId: schema.weblinkObjectTypeId,
        url: 'HTTPS://Example.COM:443/article',
        title: 'Example article',
      );
      final reusedWeblinkId = await services.creator.createWeblinkFromUrl(
        databaseId: schema.weblinkObjectTypeId,
        url: 'https://example.com/article',
        title: 'Ignored duplicate title',
      );
      expect(reusedWeblinkId, weblinkId);

      final firstImageId = await services.creator.createImageFromManagedFile(
        databaseId: schema.imageObjectTypeId,
        filePath: '/managed/cover.png',
        originalFilename: 'cover.png',
        contentType: 'image/png',
        pixelWidth: 1200,
        pixelHeight: 800,
      );
      final reusedFirstImageId =
          await services.creator.createImageFromManagedFile(
        databaseId: schema.imageObjectTypeId,
        filePath: '/managed/cover.png',
        originalFilename: 'renamed-cover.png',
        contentType: 'image/png',
      );
      expect(reusedFirstImageId, firstImageId);

      final secondImageId = await services.creator.createImageFromManagedFile(
        databaseId: schema.imageObjectTypeId,
        filePath: '/managed/related.png',
        originalFilename: 'related.png',
        contentType: 'image/png',
        pixelWidth: 600,
        pixelHeight: 900,
      );

      final representativeContext = await services.relationEditor.load(
        workspaceId: workspaceId,
        sourceObjectId: weblinkId,
        property: schema.representativeImageProperty,
      );
      expect(
        representativeContext.candidates.map((object) => object.id).toSet(),
        containsAll(<int>{firstImageId, secondImageId}),
      );
      await services.relationEditor.save(
        context: representativeContext,
        selectedObjectIds: <int>[firstImageId],
      );
      await services.relationEditor.save(
        context: representativeContext,
        selectedObjectIds: <int>[firstImageId],
      );

      final relatedContext = await services.relationEditor.load(
        workspaceId: workspaceId,
        sourceObjectId: weblinkId,
        property: schema.relatedImagesProperty,
      );
      await services.relationEditor.save(
        context: relatedContext,
        selectedObjectIds: <int>[firstImageId, secondImageId],
      );
      await services.relationEditor.save(
        context: relatedContext,
        selectedObjectIds: <int>[firstImageId, secondImageId],
      );

      final reads = RelationReadService(objectStore);
      final resolvedOutgoing = await reads.outgoing(
        sourceObjectTypeId: schema.weblinkObjectTypeId,
        sourceObjectId: weblinkId,
      );
      final representativeEdges = resolvedOutgoing
          .where(
            (item) =>
                item.property.id == schema.representativeImageProperty.id,
          )
          .toList();
      final relatedEdges = resolvedOutgoing
          .where((item) => item.property.id == schema.relatedImagesProperty.id)
          .toList();
      expect(representativeEdges, hasLength(1));
      expect(representativeEdges.single.targetObject.id, firstImageId);
      expect(
        relatedEdges.map((item) => item.targetObject.id).toSet(),
        <int>{firstImageId, secondImageId},
      );
      expect(await objectStore.outgoingRelations(weblinkId), hasLength(3));

      final firstBacklinks = await reads.backlinks(
        workspaceId: workspaceId,
        targetObjectId: firstImageId,
      );
      final secondBacklinks = await reads.backlinks(
        workspaceId: workspaceId,
        targetObjectId: secondImageId,
      );
      expect(firstBacklinks, hasLength(2));
      expect(
        firstBacklinks.map((item) => item.property.id).toSet(),
        <int>{
          schema.representativeImageProperty.id,
          schema.relatedImagesProperty.id,
        },
      );
      expect(secondBacklinks, hasLength(1));
      expect(secondBacklinks.single.property.id, schema.relatedImagesProperty.id);

      final integrity = RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
