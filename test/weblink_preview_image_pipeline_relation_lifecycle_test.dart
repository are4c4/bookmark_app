import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_index_reconcile_service.dart';
import 'package:bookmark_app/data/relation_index_service.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/remote_image_storage_service.dart';
import 'package:bookmark_app/services/weblink_preview_image_pipeline.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Fixture {
  _Fixture({
    required this.database,
    required this.directory,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.defaultsStore,
    required this.systemObjects,
    required this.weblink,
    required this.schema,
    required this.pipeline,
    required this.requestCount,
  });

  final AppDatabase database;
  final Directory directory;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final ObjectTypeDefaultsStore defaultsStore;
  final SystemObjectStore systemObjects;
  final AppObject weblink;
  final WeblinkImageSchemaDefinition schema;
  final WeblinkPreviewImagePipeline pipeline;
  final int Function() requestCount;

  BidirectionalRelationStore get bidirectionalStore => BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      );

  RelationMutationService get mutations => RelationMutationService(
        objectStore: objectStore,
        genericStore: genericStore,
        bidirectionalStore: bidirectionalStore,
      );

  RelationIntegrityService get integrity => RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
      );
}

Future<_Fixture> _fixture() async {
  final directory = await Directory.systemTemp.createTemp('relation_preview_');
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final workspaceId = await WorkspaceStore(database).initialize();
  final genericStore = GenericDatabaseStore(database);
  final objectStore = ObjectStore(genericStore);
  final defaultsStore = ObjectTypeDefaultsStore(genericStore);
  final systemObjects = SystemObjectStore(
    database: database,
    objectStore: objectStore,
  );
  final weblinks = WeblinkObjectService(
    systemObjects: systemObjects,
    defaultsStore: defaultsStore,
  );
  final weblink = await weblinks.findOrCreate(
    workspaceId: workspaceId,
    url: 'https://example.com/relation-preview',
  );
  await weblinks.enrichIfMissing(
    workspaceId: workspaceId,
    objectId: weblink.id,
    previewImageUrl: 'https://cdn.example.com/relation-preview.jpg',
  );
  final schema = await WeblinkImageSchemaService(
    systemObjects: systemObjects,
    defaultsStore: defaultsStore,
  ).ensureDefinition(workspaceId);
  var requests = 0;
  final pipeline = WeblinkPreviewImagePipeline(
    database: database,
    objectStore: objectStore,
    systemObjectStore: systemObjects,
    remoteStorage: RemoteImageStorageService(
      client: MockClient((request) async {
        requests += 1;
        return http.Response.bytes(
          <int>[1, 2, 3, 4],
          200,
          headers: const <String, String>{'content-type': 'image/jpeg'},
        );
      }),
      storage: PhotoStorageService(photoDirectoryPath: directory.path),
    ),
  );
  return _Fixture(
    database: database,
    directory: directory,
    workspaceId: workspaceId,
    genericStore: genericStore,
    objectStore: objectStore,
    defaultsStore: defaultsStore,
    systemObjects: systemObjects,
    weblink: weblink,
    schema: schema,
    pipeline: pipeline,
    requestCount: () => requests,
  );
}

void main() {
  test('production preview pipeline retry is Relation-idempotent', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    addTearDown(() => fixture.directory.delete(recursive: true));

    final firstImageId = await fixture.pipeline.ingestIfMissing(
      workspaceId: fixture.workspaceId,
      weblinkObjectId: fixture.weblink.id,
    );
    final secondImageId = await fixture.pipeline.ingestIfMissing(
      workspaceId: fixture.workspaceId,
      weblinkObjectId: fixture.weblink.id,
    );

    expect(firstImageId, isNotNull);
    expect(secondImageId, firstImageId);
    expect(fixture.requestCount(), 1);
    final refreshed = (await fixture.objectStore.listObjects(
      fixture.schema.weblinkObjectTypeId,
    ))
        .singleWhere((object) => object.id == fixture.weblink.id);
    expect(
      ObjectRelationValue.fromJson(
        refreshed.values[fixture.schema.representativeImageProperty.id],
      ).objectIds,
      <int>[firstImageId!],
    );
    final edges = (await fixture.objectStore.outgoingRelations(fixture.weblink.id))
        .where(
          (edge) =>
              edge.propertyId == fixture.schema.representativeImageProperty.id,
        )
        .toList(growable: false);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, firstImageId);
    final backlinks = await fixture.objectStore.backlinks(firstImageId);
    expect(
      backlinks.where(
        (edge) =>
            edge.sourceObjectId == fixture.weblink.id &&
            edge.propertyId == fixture.schema.representativeImageProperty.id,
      ),
      hasLength(1),
    );
    expect(
      (await fixture.integrity.auditWorkspace(fixture.workspaceId)).isHealthy,
      isTrue,
    );
  });

  test('pipeline-created representative can be canonically replaced', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    addTearDown(() => fixture.directory.delete(recursive: true));

    final firstImageId = (await fixture.pipeline.ingestIfMissing(
      workspaceId: fixture.workspaceId,
      weblinkObjectId: fixture.weblink.id,
    ))!;
    final replacementFile = File('${fixture.directory.path}/replacement.jpg');
    await replacementFile.writeAsBytes(<int>[9, 8, 7]);
    final replacement = await ImageObjectService(
      systemObjects: fixture.systemObjects,
      defaultsStore: fixture.defaultsStore,
    ).findOrCreateManaged(
      workspaceId: fixture.workspaceId,
      filePath: replacementFile.path,
      sourceUrl: 'https://cdn.example.com/replacement.jpg',
      originalFilename: 'replacement.jpg',
      contentType: 'image/jpeg',
    );

    await fixture.mutations.setRelation(
      objectId: fixture.weblink.id,
      property: fixture.schema.representativeImageProperty,
      targetObjectIds: <int>[replacement.id],
    );

    final refreshed = (await fixture.objectStore.listObjects(
      fixture.schema.weblinkObjectTypeId,
    ))
        .singleWhere((object) => object.id == fixture.weblink.id);
    expect(
      ObjectRelationValue.fromJson(
        refreshed.values[fixture.schema.representativeImageProperty.id],
      ).objectIds,
      <int>[replacement.id],
    );
    final edges = (await fixture.objectStore.outgoingRelations(fixture.weblink.id))
        .where(
          (edge) =>
              edge.propertyId == fixture.schema.representativeImageProperty.id,
        )
        .toList(growable: false);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, replacement.id);
    expect(await fixture.objectStore.backlinks(firstImageId), isEmpty);
    final replacementBacklinks =
        await fixture.objectStore.backlinks(replacement.id);
    expect(
      replacementBacklinks.where(
        (edge) =>
            edge.sourceObjectId == fixture.weblink.id &&
            edge.propertyId == fixture.schema.representativeImageProperty.id,
      ),
      hasLength(1),
    );
    expect(
      (await fixture.integrity.auditWorkspace(fixture.workspaceId)).isHealthy,
      isTrue,
    );
  });

  test('pipeline Relation index-only drift reconciles from persisted value',
      () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    addTearDown(() => fixture.directory.delete(recursive: true));

    final imageId = (await fixture.pipeline.ingestIfMissing(
      workspaceId: fixture.workspaceId,
      weblinkObjectId: fixture.weblink.id,
    ))!;
    await fixture.database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      <Object>[
        fixture.weblink.id,
        fixture.schema.representativeImageProperty.id,
      ],
    );

    final before = await fixture.integrity.auditWorkspace(fixture.workspaceId);
    expect(
      before.issuesOf(RelationIntegrityIssueKind.missingIndexEdge),
      hasLength(1),
    );
    final reconcile = RelationIndexReconcileService(
      integrityService: fixture.integrity,
      indexService: RelationIndexService(fixture.objectStore),
    );
    final result = await reconcile.reconcileWorkspace(fixture.workspaceId);

    expect(result.rebuilt, isTrue);
    expect(result.after.isHealthy, isTrue);
    final refreshed = (await fixture.objectStore.listObjects(
      fixture.schema.weblinkObjectTypeId,
    ))
        .singleWhere((object) => object.id == fixture.weblink.id);
    expect(
      ObjectRelationValue.fromJson(
        refreshed.values[fixture.schema.representativeImageProperty.id],
      ).objectIds,
      <int>[imageId],
    );
    final edges = (await fixture.objectStore.outgoingRelations(fixture.weblink.id))
        .where(
          (edge) =>
              edge.propertyId == fixture.schema.representativeImageProperty.id,
        )
        .toList(growable: false);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, imageId);
  });

  test('deleting pipeline-managed Image detaches surviving Weblink', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    addTearDown(() => fixture.directory.delete(recursive: true));

    final imageId = (await fixture.pipeline.ingestIfMissing(
      workspaceId: fixture.workspaceId,
      weblinkObjectId: fixture.weblink.id,
    ))!;
    await fixture.mutations.deleteObject(
      workspaceId: fixture.workspaceId,
      objectTypeId: fixture.schema.imageObjectTypeId,
      objectId: imageId,
    );

    final refreshed = (await fixture.objectStore.listObjects(
      fixture.schema.weblinkObjectTypeId,
    ))
        .singleWhere((object) => object.id == fixture.weblink.id);
    expect(
      ObjectRelationValue.fromJson(
        refreshed.values[fixture.schema.representativeImageProperty.id],
      ).objectIds,
      isEmpty,
    );
    expect(
      (await fixture.objectStore.outgoingRelations(fixture.weblink.id)).where(
        (edge) =>
            edge.propertyId == fixture.schema.representativeImageProperty.id,
      ),
      isEmpty,
    );
    expect(await fixture.objectStore.backlinks(imageId), isEmpty);
    expect(
      (await fixture.integrity.auditWorkspace(fixture.workspaceId)).isHealthy,
      isTrue,
    );
  });
}
