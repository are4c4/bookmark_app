import 'bidirectional_relation_store.dart';
import 'database_collection_config_service.dart';
import 'database_collection_resolver.dart';
import 'database_collection_store.dart';
import 'generic_database_collection_page_data.dart';
import 'generic_database_object_create_service.dart';
import 'generic_database_store.dart';
import 'object_board_create_service.dart';
import 'object_relation_editor_service.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';

/// Composition root for Object-owned services consumed by GenericDatabasePage.
///
/// Keeping the canonical collection, creation and Relation adapters assembled in
/// one place reduces the amount of dependency wiring that the large page must
/// own during the ObjectType != Database migration. Behavior remains delegated
/// to the focused services rather than being reimplemented here.
class GenericDatabasePageServices {
  const GenericDatabasePageServices({
    required this.loader,
    required this.creator,
    required this.relationEditor,
    required this.collectionConfig,
  });

  factory GenericDatabasePageServices.fromStores({
    required GenericDatabaseStore genericStore,
    required ObjectStore objectStore,
  }) {
    final collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final collectionResolver = DatabaseCollectionResolver(
      collectionStore: collectionStore,
      objectStore: objectStore,
    );
    final loader = GenericDatabaseCollectionPageLoader(
      genericStore: genericStore,
      collectionResolver: collectionResolver,
    );
    final relationMutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
    );

    return GenericDatabasePageServices(
      loader: loader,
      creator: GenericDatabaseObjectCreateService(
        pageLoader: loader,
        objectStore: objectStore,
        boardCreate: ObjectBoardCreateService(
          objectStore,
          relationMutations: relationMutations,
        ),
      ),
      relationEditor: ObjectRelationEditorService(
        targets: RelationTargetService(objectStore),
        mutations: relationMutations,
      ),
      collectionConfig: DatabaseCollectionConfigService(
        collectionStore: collectionStore,
        objectStore: objectStore,
      ),
    );
  }

  final GenericDatabaseCollectionPageLoader loader;
  final GenericDatabaseObjectCreateService creator;
  final ObjectRelationEditorService relationEditor;
  final DatabaseCollectionConfigService collectionConfig;
}
