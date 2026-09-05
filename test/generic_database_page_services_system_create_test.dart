import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
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
}
