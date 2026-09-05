import 'dart:io';

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
import 'package:bookmark_app/services/bookmark_metadata_service.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/remote_image_storage_service.dart';
import 'package:bookmark_app/services/weblink_preview_image_pipeline.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'direct Weblink enrichment creates one canonical Representative Image Relation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'relation_direct_weblink_enrichment_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final defaultsStore = ObjectTypeDefaultsStore(genericStore);
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final schema = await WeblinkImageSchemaService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      ).ensureDefinition(workspaceId);

      var previewRequests = 0;
      final pipeline = WeblinkPreviewImagePipeline(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
        remoteStorage: RemoteImageStorageService(
          client: MockClient((request) async {
            previewRequests += 1;
            return http.Response.bytes(
              <int>[1, 2, 3, 4],
              200,
              headers: const <String, String>{
                'content-type': 'image/jpeg',
              },
            );
          }),
          storage: PhotoStorageService(photoDirectoryPath: directory.path),
        ),
      );
      final services = GenericDatabasePageServices.fromStores(
        genericStore: genericStore,
        objectStore: objectStore,
        weblinkMetadataFetch: (_) async => const BookmarkMetadata(
          url: 'https://resource.test/article',
          title: 'Resource page title',
          description: 'Resource description',
          thumbnail: 'https://cdn.resource.test/preview.jpg',
        ),
        weblinkPreviewImageIngest: pipeline.ingestIfMissing,
      );

      final firstWeblinkId = await services.creator.createWeblinkFromUrl(
        databaseId: schema.weblinkObjectTypeId,
        url: 'HTTPS://RESOURCE.TEST:443/article',
      );
      final reusedWeblinkId = await services.creator.createWeblinkFromUrl(
        databaseId: schema.weblinkObjectTypeId,
        url: 'https://resource.test/article',
      );

      expect(reusedWeblinkId, firstWeblinkId);
      expect(previewRequests, 1);

      final images = await objectStore.listObjects(schema.imageObjectTypeId);
      expect(images, hasLength(1));
      final imageId = images.single.id;

      final reads = RelationReadService(objectStore);
      final outgoing = await reads.outgoing(
        sourceObjectTypeId: schema.weblinkObjectTypeId,
        sourceObjectId: firstWeblinkId,
      );
      final representative = outgoing
          .where(
            (item) =>
                item.property.id == schema.representativeImageProperty.id,
          )
          .toList(growable: false);
      expect(representative, hasLength(1));
      expect(representative.single.targetObject.id, imageId);

      final normalizedEdges = (await objectStore.outgoingRelations(
        firstWeblinkId,
      ))
          .where(
            (edge) =>
                edge.propertyId == schema.representativeImageProperty.id,
          )
          .toList(growable: false);
      expect(normalizedEdges, hasLength(1));
      expect(normalizedEdges.single.targetObjectId, imageId);

      final backlinks = await reads.backlinks(
        workspaceId: workspaceId,
        targetObjectId: imageId,
      );
      final representativeBacklinks = backlinks
          .where(
            (item) =>
                item.sourceObject.id == firstWeblinkId &&
                item.property.id == schema.representativeImageProperty.id,
          )
          .toList(growable: false);
      expect(representativeBacklinks, hasLength(1));

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
