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
  late GenericDatabaseImageImportService importService;
  late PhotoStorageService photoStorage;
  late Directory tempDirectory;
  late Directory managedDirectory;
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
    final objectCreate = GenericDatabaseObjectCreateService(
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

    tempDirectory = await Directory.systemTemp.createTemp('image_reimport_');
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
      image.encodePng(image.Image(width: 2, height: 1)),
    );
    return file;
  }

  List<File> managedFiles() => managedDirectory.existsSync()
      ? managedDirectory.listSync().whereType<File>().toList()
      : const <File>[];

  test('canonical Image reimport reuses byte-identical managed file and Object',
      () async {
    final source = await writeTinyPng('same.png');
    final definition = await images.ensureDefinition(workspaceId);

    final firstIds = await importService.importPaths(
      databaseId: definition.objectType.id,
      sourcePaths: <String>[source.path],
    );
    final firstFiles = managedFiles();
    expect(firstIds, hasLength(1));
    expect(firstFiles, hasLength(1));

    final secondIds = await importService.importPaths(
      databaseId: definition.objectType.id,
      sourcePaths: <String>[source.path],
    );

    expect(secondIds, firstIds);
    expect(managedFiles(), hasLength(1));
    expect(await objectStore.listObjects(definition.objectType.id), hasLength(1));
    expect(firstFiles.single.path, managedFiles().single.path);
  });

  test('duplicate content in one batch returns each canonical Image id once',
      () async {
    final firstSource = await writeTinyPng('first.png');
    final secondSource = await writeTinyPng('second.png');
    final definition = await images.ensureDefinition(workspaceId);

    final ids = await importService.importPaths(
      databaseId: definition.objectType.id,
      sourcePaths: <String>[firstSource.path, secondSource.path],
    );

    expect(ids, hasLength(1));
    expect(managedFiles(), hasLength(1));
    expect(await objectStore.listObjects(definition.objectType.id), hasLength(1));
  });

  test('failed Image creation never deletes a reused pre-existing managed file',
      () async {
    final source = await writeTinyPng('preserve.png');
    final seeded = await photoStorage.importPaths(
      <String>[source.path],
      reuseIdentical: true,
    );
    expect(seeded.single.createdNew, isTrue);
    final existingPath = seeded.single.path;
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

    expect(await File(existingPath).exists(), isTrue);
    expect(managedFiles(), hasLength(1));
  });

  test('legacy/default PhotoStorage import still creates independent copies',
      () async {
    final source = await writeTinyPng('legacy.png');

    final first = await photoStorage.importPaths(<String>[source.path]);
    final second = await photoStorage.importPaths(<String>[source.path]);

    expect(first.single.createdNew, isTrue);
    expect(second.single.createdNew, isTrue);
    expect(second.single.path, isNot(first.single.path));
    expect(managedFiles(), hasLength(2));
  });
}
