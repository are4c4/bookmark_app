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
import 'package:bookmark_app/services/remote_image_storage_service.dart';
import 'package:bookmark_app/services/weblink_preview_image_pipeline.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'preview pipeline reuses non-canonical stored Image source before download',
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

      final images = ImageObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      );
      final definition = await images.ensureDefinition(workspaceId);
      final existingImage = await images.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/existing.png',
        sourceUrl: 'https://cdn.example.org/cover.png',
        originalFilename: 'existing.png',
      );
      await objectStore.setPropertyValue(
        objectId: existingImage.id,
        property: definition.sourceUrlProperty,
        value: 'HTTPS://CDN.Example.ORG:443/a/../cover.png',
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
      expect(
        await objectStore.listObjects(definition.objectType.id),
        hasLength(1),
      );

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
        <int>[existingImage.id],
      );
    },
  );
}
