import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late SystemObjectStore systemObjects;
  late WeblinkObjectService weblinks;
  late GenericDatabaseObjectCreateService service;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
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
      weblinks: weblinks,
    );
  });

  tearDown(() => database.close());

  test('URL collection creation normalizes and reuses canonical Weblink', () async {
    final definition = await weblinks.ensureDefinition(workspaceId);

    final firstId = await service.createWeblinkFromUrl(
      databaseId: definition.objectType.id,
      url: 'HTTPS://Example.com:443/articles/../guide',
      title: 'Guide',
    );
    final secondId = await service.createWeblinkFromUrl(
      databaseId: definition.objectType.id,
      url: 'https://example.com/guide',
      title: 'Different title must not duplicate',
    );

    expect(secondId, firstId);
    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.title, 'Guide');
    expect(
      objects.single.values[definition.urlProperty.id],
      'https://example.com/guide',
    );
  });

  test('URL Weblink creation rejects a non-Weblink collection before mutation', () async {
    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );

    await expectLater(
      service.createWeblinkFromUrl(
        databaseId: customTypeId,
        url: 'https://example.com/book',
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await objectStore.listObjects(customTypeId), isEmpty);
  });
}
