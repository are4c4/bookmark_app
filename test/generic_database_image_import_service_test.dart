import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/generic_database_image_import_service.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late ImageObjectService images;
  late GenericDatabaseObjectCreateService objectCreate;
  late Directory tempDirectory;
  late Directory managedDirectory;
  late PhotoStorageService photoStorage;
  late GenericDatabaseImageImportService importService;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    objectCreate = GenericDatabaseObjectCreateService(
      pageLoader: GenericDatabaseCollectionPageLoader(
        genericStore: genericStore,
        collectionResolver: DatabaseCollectionResolver(
          collectionStore: collectionStore,
          objectStore: objectStore,
        ),
      ),
      objectStore: objectStore,
      boardCreate: ObjectBoardCreateService(
        objectStore,
        relationMutations: mutations,
      ),
      systemObjects: systemObjects,
      images: images,
    );

    tempDirectory = await Directory.systemTemp.createTemp('image_import_workflow_');
    managedDirectory = Directory('${tempDirectory.path}/managed');
    photoStorage = PhotoStorageService(photoDirectoryPath: managedDirectory.path);
    importService = GenericDatabaseImageImportService(
      photoStorage: photoStorage,
      objectCreate: objectCreate,
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<File> writeTinyPng(String name) async {
    final file = File('${tempDirectory.path}/$name');
    await file.writeAsBytes(
      image.encodePng(image.Image(width: 1, height: 1)),
    );
    return file;
  }

  test('imports into managed storage before creating canonical Image Object', () async {
    final source = await writeTinyPng('source.png');
    final definition = await images.ensureDefinition(workspaceId);

    final ids = await importService.importPaths(
      databaseId: definition.objectType.id,
      sourcePaths: <String>[source.path],
    );

    expect(ids, hasLength(1));
    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects, hasLength(1));
    final object = objects.single;
    expect(object.id, ids.single);
    final managedPath = '${object.values[definition.fileProperty.id]}';
    expect(managedPath, startsWith(managedDirectory.path));
    expect(managedPath, isNot(source.path));
    expect(await File(managedPath).exists(), isTrue);
    expect(object.values[definition.originalFilenameProperty.id], 'source.png');
    expect(object.values[definition.contentTypeProperty.id], 'image/png');
    expect(object.values[definition.pixelWidthProperty.id], 1);
    expect(object.values[definition.pixelHeightProperty.id], 1);
  });

  test('removes copied managed file when collection rejects Image creation', () async {
    final source = await writeTinyPng('rejected.png');
    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );

    await expectLater(
      importService.importPaths(
        databaseId: customTypeId,
        sourcePaths: <String>[source.path],
      ),
      throwsA(isA<UnsupportedError>()),
    );

    expect(await source.exists(), isTrue);
    expect(await managedDirectory.exists(), isTrue);
    expect(managedDirectory.listSync(), isEmpty);
    expect(await objectStore.listObjects(customTypeId), isEmpty);
  });
}
