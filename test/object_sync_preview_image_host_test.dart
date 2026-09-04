import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
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
  test('live Object sync ingests one managed representative image in background',
      () async {
    final directory = await Directory.systemTemp.createTemp('preview_host_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();

    await database.customStatement(
      '''INSERT INTO bookmarks(url, title, thumbnail)
         VALUES (?, ?, ?)''',
      <Object>[
        'https://example.com/article',
        'Article',
        'HTTPS://CDN.Example.com:443/cover.jpg',
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
    addTearDown(sync.dispose);

    await sync.syncWorkspace(workspaceId);
    await sync.syncRemotePreviewImages(workspaceId);

    expect(requestCount, 1);
    final defaultsStore = ObjectTypeDefaultsStore(GenericDatabaseStore(database));
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

    final imageDefinition = await ImageObjectService(
      systemObjects: sync.systemObjectStore,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);
    final image = (await sync.objectStore.listObjects(imageDefinition.objectType.id))
        .singleWhere((object) => object.id == representativeIds.single);
    expect(
      image.values[imageDefinition.sourceUrlProperty.id],
      'https://cdn.example.com/cover.jpg',
    );
    final managedPath = '${image.values[imageDefinition.fileProperty.id]}';
    expect(await File(managedPath).exists(), isTrue);
    expect(File(managedPath).parent.path, directory.path);

    await sync.syncRemotePreviewImages(workspaceId);
    expect(requestCount, 1);
  });

  test('remote preview failure stays optional and is not retried every sync',
      () async {
    final directory = await Directory.systemTemp.createTemp('preview_host_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();

    await database.customStatement(
      '''INSERT INTO bookmarks(url, title, thumbnail)
         VALUES (?, ?, ?)''',
      <Object>[
        'https://example.net/article',
        'Article',
        'https://cdn.example.net/missing.jpg',
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
        client: MockClient((_) async {
          requestCount += 1;
          return http.Response('missing', 404);
        }),
        storage: PhotoStorageService(photoDirectoryPath: directory.path),
      ),
    );
    addTearDown(sync.dispose);

    await sync.syncWorkspace(workspaceId);
    await sync.syncRemotePreviewImages(workspaceId);
    await sync.syncWorkspace(workspaceId);
    await sync.syncRemotePreviewImages(workspaceId);

    expect(requestCount, 1);
    final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    expect(await sync.objectStore.listObjects(weblinkType.id), hasLength(1));

    final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    ))!;
    final relation = bookmarkType.properties.singleWhere(
      (property) => property.name == 'Weblink',
    );
    final bookmark = (await sync.objectStore.listObjects(bookmarkType.id)).single;
    expect(
      ObjectRelationValue.fromJson(bookmark.values[relation.id]).objectIds,
      hasLength(1),
    );

    final defaultsStore = ObjectTypeDefaultsStore(GenericDatabaseStore(database));
    final schema = await WeblinkImageSchemaService(
      systemObjects: sync.systemObjectStore,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);
    final weblink = (await sync.objectStore.listObjects(
      schema.weblinkObjectTypeId,
    ))
        .single;
    expect(
      ObjectRelationValue.fromJson(
        weblink.values[schema.representativeImageProperty.id],
      ).objectIds,
      isEmpty,
    );
  });
}
