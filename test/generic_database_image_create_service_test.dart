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
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late ImageObjectService images;
  late GenericDatabaseObjectCreateService service;
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
    service = GenericDatabaseObjectCreateService(
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
  });

  tearDown(() => database.close());

  test('managed file collection creation reuses canonical Image identity', () async {
    final definition = await images.ensureDefinition(workspaceId);

    final firstId = await service.createImageFromManagedFile(
      databaseId: definition.objectType.id,
      filePath: '/managed/example.png',
      title: 'Example',
      originalFilename: 'example.png',
      contentType: 'image/png',
      pixelWidth: 1200,
      pixelHeight: 800,
    );
    final secondId = await service.createImageFromManagedFile(
      databaseId: definition.objectType.id,
      filePath: '/managed/example.png',
      title: 'Different title must not duplicate',
    );

    expect(secondId, firstId);
    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.title, 'Example');
    expect(objects.single.values[definition.fileProperty.id], '/managed/example.png');
    expect(objects.single.values[definition.originalFilenameProperty.id], 'example.png');
    expect(objects.single.values[definition.contentTypeProperty.id], 'image/png');
    expect(objects.single.values[definition.pixelWidthProperty.id], 1200);
    expect(objects.single.values[definition.pixelHeightProperty.id], 800);
  });

  test('managed Image creation rejects a non-Image collection before mutation', () async {
    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );

    await expectLater(
      service.createImageFromManagedFile(
        databaseId: customTypeId,
        filePath: '/managed/book.png',
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await objectStore.listObjects(customTypeId), isEmpty);
  });
}
