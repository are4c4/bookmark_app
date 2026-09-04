import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production Weblink Image Relations write idempotently and delete safely',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final defaultsStore = ObjectTypeDefaultsStore(genericStore);
      final schema = await WeblinkImageSchemaService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      ).ensureDefinition(workspaceId);
      final weblinks = WeblinkObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      );
      final images = ImageObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      );
      final weblink = await weblinks.findOrCreate(
        workspaceId: workspaceId,
        url: 'https://example.com/article',
      );
      final firstImage = await images.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/first.jpg',
        sourceUrl: 'https://cdn.example.com/first.jpg',
      );
      final secondImage = await images.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/second.jpg',
        sourceUrl: 'https://cdn.example.com/second.jpg',
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
      // Re-applying the same targets must not duplicate normalized edges.
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

      var persisted = (await objectStore.listObjects(schema.weblinkObjectTypeId))
          .singleWhere((object) => object.id == weblink.id);
      expect(
        ObjectRelationValue.fromJson(
          persisted.values[schema.representativeImageProperty.id],
        ).objectIds,
        <int>[firstImage.id],
      );
      expect(
        ObjectRelationValue.fromJson(
          persisted.values[schema.relatedImagesProperty.id],
        ).objectIds,
        <int>[firstImage.id, secondImage.id],
      );
      final edges = await objectStore.outgoingRelations(weblink.id);
      expect(
        edges.where(
          (edge) => edge.propertyId == schema.representativeImageProperty.id,
        ),
        hasLength(1),
      );
      expect(
        edges.where((edge) => edge.propertyId == schema.relatedImagesProperty.id),
        hasLength(2),
      );
      expect(await objectStore.backlinks(firstImage.id), hasLength(2));
      expect(await objectStore.backlinks(secondImage.id), hasLength(1));

      final integrity = RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);

      await mutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: schema.imageObjectTypeId,
        objectId: firstImage.id,
      );

      persisted = (await objectStore.listObjects(schema.weblinkObjectTypeId))
          .singleWhere((object) => object.id == weblink.id);
      expect(
        ObjectRelationValue.fromJson(
          persisted.values[schema.representativeImageProperty.id],
        ).objectIds,
        isEmpty,
      );
      expect(
        ObjectRelationValue.fromJson(
          persisted.values[schema.relatedImagesProperty.id],
        ).objectIds,
        <int>[secondImage.id],
      );
      expect(await objectStore.backlinks(firstImage.id), isEmpty);
      expect(await objectStore.backlinks(secondImage.id), hasLength(1));
      final remainingEdges = await objectStore.outgoingRelations(weblink.id);
      expect(
        remainingEdges.where(
          (edge) => edge.propertyId == schema.representativeImageProperty.id,
        ),
        isEmpty,
      );
      final relatedEdges = remainingEdges
          .where((edge) => edge.propertyId == schema.relatedImagesProperty.id)
          .toList(growable: false);
      expect(relatedEdges, hasLength(1));
      expect(relatedEdges.single.targetObjectId, secondImage.id);
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
