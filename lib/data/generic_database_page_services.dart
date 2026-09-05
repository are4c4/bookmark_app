import 'bidirectional_relation_store.dart';
import 'daily_note_service.dart';
import 'database_collection_config_service.dart';
import 'database_collection_resolver.dart';
import 'database_collection_store.dart';
import 'database_view_open_mode_service.dart';
import 'database_view_store.dart';
import 'generic_database_collection_page_data.dart';
import 'generic_database_object_create_service.dart';
import 'generic_database_store.dart';
import 'image_object_service.dart';
import 'object_alias_store.dart';
import 'object_board_create_service.dart';
import 'object_identity_search_service.dart';
import 'object_open_presentation_service.dart';
import 'object_relation_editor_service.dart';
import 'object_store.dart';
import 'object_type_defaults_store.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';
import 'system_object_store.dart';
import 'weblink_object_service.dart';

/// Composition root for Object-owned services consumed by GenericDatabasePage.
///
/// Keeping the canonical collection, creation, Relation and Object-opening
/// adapters assembled in one place reduces the amount of dependency wiring that
/// the large page must own during the ObjectType != Database migration. Behavior
/// remains delegated to the focused services rather than being reimplemented
/// here.
class GenericDatabasePageServices {
  const GenericDatabasePageServices({
    required this.loader,
    required this.creator,
    required this.relationEditor,
    required this.relationMutations,
    required this.collectionConfig,
    required this.openPresentation,
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
    final viewStore = DatabaseViewStore(genericStore.database);
    final identitySearch = ObjectIdentitySearchService(
      objectStore: objectStore,
      aliasStore: ObjectAliasStore(genericStore),
    );
    final systemObjects = SystemObjectStore(
      database: genericStore.database,
      objectStore: objectStore,
    );
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final dailyNotes = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
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
        systemObjects: systemObjects,
        dailyNotes: dailyNotes,
        weblinks: weblinks,
        images: images,
      ),
      relationEditor: ObjectRelationEditorService(
        targets: RelationTargetService(objectStore),
        mutations: relationMutations,
        identitySearch: identitySearch,
      ),
      relationMutations: relationMutations,
      collectionConfig: DatabaseCollectionConfigService(
        collectionStore: collectionStore,
        objectStore: objectStore,
      ),
      openPresentation: ObjectOpenPresentationService(
        viewOpenModes: DatabaseViewOpenModeService(viewStore),
        objectTypeDefaults: defaultsStore,
      ),
    );
  }

  final GenericDatabaseCollectionPageLoader loader;
  final GenericDatabaseObjectCreateService creator;
  final ObjectRelationEditorService relationEditor;
  final RelationMutationService relationMutations;
  final DatabaseCollectionConfigService collectionConfig;
  final ObjectOpenPresentationService openPresentation;
}
