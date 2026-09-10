import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generic Person create preserves canonical and legacy authority',
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
      final personBridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
      );
      final personSchema = await personBridge.ensurePersonObjectType(
        workspaceId,
      );
      final collectionStore = DatabaseCollectionStore(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final relationMutations = RelationMutationService(
        objectStore: objectStore,
        genericStore: genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
      );
      final service = GenericDatabaseObjectCreateService(
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
          relationMutations: relationMutations,
        ),
        systemObjects: systemObjects,
      );

      final objectId = await service.create(
        databaseId: personSchema.objectType.id,
        title: 'Ada Lovelace',
      );

      final objects = await objectStore.listObjects(personSchema.objectType.id);
      expect(objects, hasLength(1));
      expect(objects.single.id, objectId);
      expect(objects.single.title, 'Ada Lovelace');

      final legacyPeople = await database.select(database.people).get();
      expect(legacyPeople, hasLength(1));
      expect(legacyPeople.single.name, 'Ada Lovelace');
      expect(
        await personBridge.objectIdForLegacyPerson(
          workspaceId,
          legacyPeople.single.id,
        ),
        objectId,
      );
    },
  );
}
