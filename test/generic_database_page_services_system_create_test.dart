import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_metadata_service.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('page services wire canonical Weblink and Image creation facades',
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
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final weblinkDefinition = await weblinks.ensureDefinition(workspaceId);
    final imageDefinition = await images.ensureDefinition(workspaceId);
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final weblinkId = await services.creator.createWeblinkFromUrl(
      databaseId: weblinkDefinition.objectType.id,
      url: 'HTTPS://Example.COM:443',
      title: 'Example',
    );
    final createdWeblink = (await objectStore.listObjects(
      weblinkDefinition.objectType.id,
    ))
        .singleWhere((object) => object.id == weblinkId);
    expect(
      createdWeblink.values[weblinkDefinition.urlProperty.id],
      'https://example.com/',
    );

    final imageId = await services.creator.createImageFromManagedFile(
      databaseId: imageDefinition.objectType.id,
      filePath: '/managed/example.png',
      originalFilename: 'example.png',
      contentType: 'image/png',
      pixelWidth: 1200,
      pixelHeight: 800,
    );
    final createdImage = (await objectStore.listObjects(
      imageDefinition.objectType.id,
    ))
        .singleWhere((object) => object.id == imageId);
    expect(
      createdImage.values[imageDefinition.fileProperty.id],
      '/managed/example.png',
    );
    expect(
      createdImage.values[imageDefinition.originalFilenameProperty.id],
      'example.png',
    );
    expect(imageDefinition.aspectRatioFor(createdImage), 1.5);
  });

  test('page services enrich direct Weblink creation through focused callbacks',
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
    final definition = await WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    ).ensureDefinition(workspaceId);
    var previewObjectId = 0;
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
      weblinkMetadataFetch: (_) async => const BookmarkMetadata(
        url: 'https://resource.test/article',
        title: 'Resource page title',
        description: 'Resource description',
        thumbnail: 'https://resource.test/preview.jpg',
      ),
      weblinkPreviewImageIngest: ({
        required workspaceId,
        required weblinkObjectId,
      }) async {
        previewObjectId = weblinkObjectId;
        return null;
      },
    );

    final weblinkId = await services.creator.createWeblinkFromUrl(
      databaseId: definition.objectType.id,
      url: 'https://resource.test/article',
    );

    final created = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == weblinkId);
    expect(created.title, 'Resource page title');
    expect(
      created.values[definition.pageTitleProperty.id],
      'Resource page title',
    );
    expect(
      created.values[definition.descriptionProperty.id],
      'Resource description',
    );
    expect(
      created.values[definition.previewImageUrlProperty.id],
      'https://resource.test/preview.jpg',
    );
    expect(previewObjectId, weblinkId);
  });

  test('page services expose managed file import through the canonical creator',
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
    final imageDefinition = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    ).ensureDefinition(workspaceId);
    final sourceDirectory = await Directory.systemTemp.createTemp(
      'bookmark_page_image_source_',
    );
    final managedDirectory = await Directory.systemTemp.createTemp(
      'bookmark_page_image_managed_',
    );
    addTearDown(() => sourceDirectory.delete(recursive: true));
    addTearDown(() => managedDirectory.delete(recursive: true));
    final source = File('${sourceDirectory.path}/picked.png');
    await source.writeAsBytes(const <int>[0, 1, 2, 3]);

    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
      photoStorage: PhotoStorageService(
        photoDirectoryPath: managedDirectory.path,
      ),
    );

    final ids = await services.imageImport.importPaths(
      databaseId: imageDefinition.objectType.id,
      sourcePaths: <String>[source.path],
    );

    expect(ids, hasLength(1));
    final created = (await objectStore.listObjects(
      imageDefinition.objectType.id,
    ))
        .singleWhere((object) => object.id == ids.single);
    final managedPath = '${created.values[imageDefinition.fileProperty.id]}';
    expect(managedPath, startsWith(managedDirectory.path));
    expect(await File(managedPath).exists(), isTrue);
    expect(
      created.values[imageDefinition.originalFilenameProperty.id],
      'picked.png',
    );
    expect(
      created.values[imageDefinition.contentTypeProperty.id],
      'image/png',
    );
  });
}
