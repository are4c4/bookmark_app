import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/remote_image_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'live preview sync host keeps Representative Relation lifecycle healthy',
    () async {
      final directory =
          await Directory.systemTemp.createTemp('relation_preview_host_');
      addTearDown(() => directory.delete(recursive: true));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();

      await database.customStatement(
        '''INSERT INTO bookmarks(url, title, thumbnail)
           VALUES (?, ?, ?)''',
        <Object>[
          'https://example.com/live-relation',
          'Live Relation',
          'https://cdn.example.com/live-relation.jpg',
        ],
      );
      final bookmarkId = (await database.customSelect(
        'SELECT id FROM bookmarks LIMIT 1',
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        <Object>[bookmarkId, workspaceId],
      );

      var requestCount = 0;
      final sync = ObjectSyncService(
        database,
        enableRemotePreviewImages: true,
        remoteImageStorage: RemoteImageStorageService(
          client: MockClient((request) async {
            requestCount += 1;
            expect(
              request.url.toString(),
              'https://cdn.example.com/live-relation.jpg',
            );
            return http.Response.bytes(
              <int>[1, 2, 3, 4],
              200,
              headers: const <String, String>{'content-type': 'image/jpeg'},
            );
          }),
          storage: PhotoStorageService(photoDirectoryPath: directory.path),
        ),
      );
      addTearDown(sync.dispose);

      await sync.syncWorkspace(workspaceId);
      await sync.syncRemotePreviewImages(workspaceId);

      expect(requestCount, 1);
      final genericStore = GenericDatabaseStore(database);
      final defaultsStore = ObjectTypeDefaultsStore(genericStore);
      final schema = await WeblinkImageSchemaService(
        systemObjects: sync.systemObjectStore,
        defaultsStore: defaultsStore,
      ).ensureDefinition(workspaceId);
      final weblink = (await sync.objectStore.listObjects(
        schema.weblinkObjectTypeId,
      ))
          .single;
      final representativeIds = ObjectRelationValue.fromJson(
        weblink.values[schema.representativeImageProperty.id],
      ).objectIds;
      expect(representativeIds, hasLength(1));
      final imageId = representativeIds.single;

      final edges = (await sync.objectStore.outgoingRelations(weblink.id))
          .where(
            (edge) =>
                edge.propertyId == schema.representativeImageProperty.id,
          )
          .toList(growable: false);
      expect(edges, hasLength(1));
      expect(edges.single.targetObjectId, imageId);

      final backlinks = await sync.objectStore.backlinks(imageId);
      expect(
        backlinks.where(
          (edge) =>
              edge.sourceObjectId == weblink.id &&
              edge.propertyId == schema.representativeImageProperty.id,
        ),
        hasLength(1),
      );

      final bidirectionalStore = BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: sync.objectStore,
      );
      final integrity = RelationIntegrityService(
        objectStore: sync.objectStore,
        bidirectionalStore: bidirectionalStore,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);

      final mutations = RelationMutationService(
        objectStore: sync.objectStore,
        genericStore: genericStore,
        bidirectionalStore: bidirectionalStore,
      );
      await mutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: schema.imageObjectTypeId,
        objectId: imageId,
      );

      final refreshed = (await sync.objectStore.listObjects(
        schema.weblinkObjectTypeId,
      ))
          .singleWhere((object) => object.id == weblink.id);
      expect(
        ObjectRelationValue.fromJson(
          refreshed.values[schema.representativeImageProperty.id],
        ).objectIds,
        isEmpty,
      );
      expect(
        (await sync.objectStore.outgoingRelations(weblink.id)).where(
          (edge) => edge.propertyId == schema.representativeImageProperty.id,
        ),
        isEmpty,
      );
      expect(await sync.objectStore.backlinks(imageId), isEmpty);
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
