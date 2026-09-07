import 'dart:async';
import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/remote_image_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'background preview finishing after Search rebuild refreshes Image and Weblink',
    () async {
      final directory =
          await Directory.systemTemp.createTemp('preview_search_refresh_');
      addTearDown(() => directory.delete(recursive: true));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();

      await database.customStatement(
        '''INSERT INTO bookmarks(url, title, thumbnail)
           VALUES (?, ?, ?)''',
        <Object>[
          'https://example.com/article',
          'Background preview article',
          'https://cdn.example.com/FreshPreviewImage.jpg',
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

      final requestStarted = Completer<void>();
      final response = Completer<http.Response>();
      final genericStore = GenericDatabaseStore(database);
      final search = ObjectGlobalSearchService(genericStore);
      var refreshCount = 0;
      final sync = ObjectSyncService(
        database,
        enableRemotePreviewImages: true,
        remoteImageStorage: RemoteImageStorageService(
          client: MockClient((request) async {
            expect(
              request.url.toString(),
              'https://cdn.example.com/FreshPreviewImage.jpg',
            );
            if (!requestStarted.isCompleted) requestStarted.complete();
            return response.future;
          }),
          storage: PhotoStorageService(photoDirectoryPath: directory.path),
        ),
        onPreviewImageIngested: (imageObjectId) async {
          refreshCount += 1;
          await search.refreshObjectLabelDependents(imageObjectId);
        },
      );
      addTearDown(sync.dispose);

      await sync.syncWorkspace(workspaceId);
      await requestStarted.future;

      // Reproduce the production race: Global Search completes its initial
      // rebuild while optional remote preview I/O is still outstanding.
      await search.rebuildWorkspace(workspaceId);
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'freshpreviewimage',
        ),
        isEmpty,
        reason: 'the preview Image does not exist when Search rebuild completes',
      );

      response.complete(
        http.Response.bytes(
          <int>[1, 2, 3, 4],
          200,
          headers: const <String, String>{'content-type': 'image/jpeg'},
        ),
      );
      await sync.syncRemotePreviewImages(workspaceId);

      final defaultsStore = ObjectTypeDefaultsStore(genericStore);
      final imageDefinition = await ImageObjectService(
        systemObjects: sync.systemObjectStore,
        defaultsStore: defaultsStore,
      ).ensureDefinition(workspaceId);
      final image =
          (await sync.objectStore.listObjects(imageDefinition.objectType.id))
              .single;
      expect(image.title, 'FreshPreviewImage.jpg');

      final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ))!;
      final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;

      final refreshedHits = await search.search(
        workspaceId: workspaceId,
        rawQuery: 'freshpreviewimage',
      );
      expect(
        refreshedHits.map((hit) => hit.object.id),
        contains(image.id),
        reason:
            'successful background ingestion must add the new Image FTS row without a workspace rebuild',
      );
      expect(
        refreshedHits.map((hit) => hit.object.id),
        contains(weblink.id),
        reason:
            'Image label-dependent refresh must update the Weblink relation-label row too',
      );

      await sync.syncRemotePreviewImages(workspaceId);
      expect(
        refreshCount,
        1,
        reason:
            'the same attempted preview must not cause duplicate completion impact in one live sync service',
      );
    },
  );

  test('post-ingestion refresh failure does not undo canonical preview success',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('preview_search_failure_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();

    await database.customStatement(
      '''INSERT INTO bookmarks(url, title, thumbnail)
         VALUES (?, ?, ?)''',
      <Object>[
        'https://example.net/article',
        'Refresh failure article',
        'https://cdn.example.net/StillCanonical.jpg',
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

    var callbackCount = 0;
    final sync = ObjectSyncService(
      database,
      enableRemotePreviewImages: true,
      remoteImageStorage: RemoteImageStorageService(
        client: MockClient((_) async => http.Response.bytes(
              <int>[4, 3, 2, 1],
              200,
              headers: const <String, String>{'content-type': 'image/jpeg'},
            )),
        storage: PhotoStorageService(photoDirectoryPath: directory.path),
      ),
      onPreviewImageIngested: (_) async {
        callbackCount += 1;
        throw StateError('private downstream refresh detail');
      },
    );
    addTearDown(sync.dispose);

    await sync.syncWorkspace(workspaceId);
    await sync.syncRemotePreviewImages(workspaceId);

    expect(callbackCount, 1);
    final imageDefinition = await ImageObjectService(
      systemObjects: sync.systemObjectStore,
      defaultsStore: ObjectTypeDefaultsStore(GenericDatabaseStore(database)),
    ).ensureDefinition(workspaceId);
    final images = await sync.objectStore.listObjects(imageDefinition.objectType.id);
    expect(images, hasLength(1));

    final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
    final representative = weblinkType.properties.singleWhere(
      (property) => property.name == 'Representative image',
    );
    expect(
      '${weblink.values[representative.id]}',
      contains('${images.single.id}'),
      reason:
          'downstream refresh failure must not roll back the canonical Representative image Relation',
    );
  });
}
