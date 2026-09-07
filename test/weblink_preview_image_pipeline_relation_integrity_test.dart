import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/remote_image_storage_service.dart';
import 'package:bookmark_app/services/weblink_preview_image_pipeline.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('malformed representative Relation fails before Image side effects',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'preview_relation_integrity_',
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
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/malformed-preview-relation',
    );
    await weblinks.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      previewImageUrl: 'https://cdn.example.com/malformed-preview.jpg',
    );
    final schema = await WeblinkImageSchemaService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);

    await genericStore.setValue(
      recordId: weblink.id,
      propertyId: schema.representativeImageProperty.id,
      value: <dynamic>['broken-image-id'],
    );

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

    await expectLater(
      pipeline.ingestIfMissing(
        workspaceId: workspaceId,
        weblinkObjectId: weblink.id,
      ),
      throwsStateError,
    );

    expect(requests, 0);
    expect(await objectStore.listObjects(schema.imageObjectTypeId), isEmpty);
    expect(await directory.list().toList(), isEmpty);

    final refreshed = (await objectStore.listObjects(schema.weblinkObjectTypeId))
        .singleWhere((object) => object.id == weblink.id);
    expect(
      refreshed.values[schema.representativeImageProperty.id],
      <dynamic>['broken-image-id'],
    );
    expect(
      (await objectStore.outgoingRelations(weblink.id)).where(
        (edge) => edge.propertyId == schema.representativeImageProperty.id,
      ),
      isEmpty,
    );
  });
}
