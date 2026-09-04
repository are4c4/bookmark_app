import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
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

void main() {
  test('preview pipeline downloads once, creates Image, and attaches canonical Relation',
      () async {
    final directory = await Directory.systemTemp.createTemp('weblink_preview_');
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
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article',
    );
    await weblinks.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      previewImageUrl: 'HTTPS://CDN.Example.com:443/cover.jpg',
    );

    var requestCount = 0;
    final pipeline = WeblinkPreviewImagePipeline(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      remoteStorage: RemoteImageStorageService(
        client: MockClient((request) async {
          requestCount += 1;
          expect(request.url.toString(), 'https://cdn.example.com/cover.jpg');
          return http.Response.bytes(
            <int>[1, 2, 3, 4],
            200,
            headers: const <String, String>{'content-type': 'image/jpeg'},
          );
        }),
        storage: PhotoStorageService(photoDirectoryPath: directory.path),
      ),
    );

    final firstImageId = await pipeline.ingestIfMissing(
      workspaceId: workspaceId,
      weblinkObjectId: weblink.id,
    );
    final secondImageId = await pipeline.ingestIfMissing(
      workspaceId: workspaceId,
      weblinkObjectId: weblink.id,
    );

    expect(firstImageId, isNotNull);
    expect(secondImageId, firstImageId);
    expect(requestCount, 1);

    final imageDefinition = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);
    final image = (await objectStore.listObjects(imageDefinition.objectType.id))
        .singleWhere((object) => object.id == firstImageId);
    expect(
      image.values[imageDefinition.sourceUrlProperty.id],
      'https://cdn.example.com/cover.jpg',
    );
    expect(image.values[imageDefinition.contentTypeProperty.id], 'image/jpeg');
    final managedPath = '${image.values[imageDefinition.fileProperty.id]}';
    expect(await File(managedPath).exists(), isTrue);
    expect(File(managedPath).parent.path, directory.path);

    final schema = await WeblinkImageSchemaService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);
    final refreshedWeblink = (await objectStore.listObjects(
      schema.weblinkObjectTypeId,
    ))
        .singleWhere((object) => object.id == weblink.id);
    expect(
      ObjectRelationValue.fromJson(
        refreshedWeblink.values[schema.representativeImageProperty.id],
      ).objectIds,
      <int>[firstImageId!],
    );
    expect(
      ObjectRelationValue.fromJson(
        refreshedWeblink.values[schema.relatedImagesProperty.id],
      ).objectIds,
      isEmpty,
    );
  });

  test('preview pipeline reuses existing Image provenance without redownload',
      () async {
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
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.org/article',
    );
    await weblinks.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      previewImageUrl: 'https://cdn.example.org/cover.png',
    );
    final existingImage = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/existing.png',
      sourceUrl: 'https://cdn.example.org/cover.png',
      originalFilename: 'existing.png',
      contentType: 'image/png',
    );

    var requestCount = 0;
    final pipeline = WeblinkPreviewImagePipeline(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      remoteStorage: RemoteImageStorageService(
        client: MockClient((_) async {
          requestCount += 1;
          return http.Response('should not download', 500);
        }),
      ),
    );

    final imageId = await pipeline.ingestIfMissing(
      workspaceId: workspaceId,
      weblinkObjectId: weblink.id,
    );

    expect(imageId, existingImage.id);
    expect(requestCount, 0);
  });

  test('optional remote failure leaves representative Relation empty', () async {
    final directory = await Directory.systemTemp.createTemp('weblink_preview_');
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
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.net/article',
    );
    await weblinks.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      previewImageUrl: 'https://cdn.example.net/missing.jpg',
    );
    final pipeline = WeblinkPreviewImagePipeline(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      remoteStorage: RemoteImageStorageService(
        client: MockClient((_) async => http.Response('missing', 404)),
        storage: PhotoStorageService(photoDirectoryPath: directory.path),
      ),
    );

    expect(
      await pipeline.ingestIfMissing(
        workspaceId: workspaceId,
        weblinkObjectId: weblink.id,
      ),
      isNull,
    );

    final schema = await WeblinkImageSchemaService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);
    final refreshed = (await objectStore.listObjects(schema.weblinkObjectTypeId))
        .singleWhere((object) => object.id == weblink.id);
    expect(
      ObjectRelationValue.fromJson(
        refreshed.values[schema.representativeImageProperty.id],
      ).objectIds,
      isEmpty,
    );
  });
}
