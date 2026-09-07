import 'dart:developer' as developer;

import 'package:drift/drift.dart' show Variable;

import '../services/bookmark_metadata_service.dart';
import '../services/generic_database_image_import_service.dart';
import '../services/image_managed_file_deletion_policy.dart';
import '../services/photo_storage_service.dart';
import '../services/remote_image_storage_service.dart';
import '../services/weblink_create_enrichment_service.dart';
import '../services/weblink_preview_image_pipeline.dart';
import 'bidirectional_relation_store.dart';
import 'daily_note_service.dart';
import 'database_collection_config_service.dart';
import 'database_collection_resolver.dart';
import 'database_collection_store.dart';
import 'database_property_authoring_service.dart';
import 'database_view_gallery_cover_source_service.dart';
import 'database_view_open_mode_service.dart';
import 'database_view_property_schema_service.dart';
import 'database_view_property_type_conversion_service.dart';
import 'database_view_property_type_migration_service.dart';
import 'database_view_store.dart';
import 'generic_database_collection_page_data.dart';
import 'generic_database_object_create_service.dart';
import 'generic_database_page_state_loader.dart';
import 'generic_database_store.dart';
import 'image_object_service.dart';
import 'object_alias_store.dart';
import 'object_board_create_service.dart';
import 'object_board_move_service.dart';
import 'object_computed_value_store.dart';
import 'object_graph_query_store.dart';
import 'object_identity_search_service.dart';
import 'object_open_presentation_service.dart';
import 'object_relation_editor_service.dart';
import 'object_store.dart';
import 'object_type_defaults_store.dart';
import 'object_type_management_store.dart';
import 'relation_mutation_service.dart';
import 'relation_schema_evolution_service.dart';
import 'relation_target_service.dart';
import 'system_object_store.dart';
import 'weblink_object_service.dart';
import 'workspace_store.dart';

/// Composition root for Object-owned services consumed by GenericDatabasePage.
///
/// Keeping the canonical collection, creation, Relation, schema-authoring and
/// Object-opening adapters assembled in one place reduces the amount of
/// dependency wiring that the large page must own during the ObjectType !=
/// Database migration. Behavior remains delegated to focused services rather
/// than being reimplemented here.
class GenericDatabasePageServices {
  const GenericDatabasePageServices({
    required this.genericStore,
    required this.objectStore,
    required this.loader,
    required this.creator,
    required this.imageImport,
    required this.relationEditor,
    required this.relationMutations,
    required this.propertyAuthoring,
    required this.propertySchema,
    required this.relationSchemaEvolution,
    required this.valueTypeConversion,
    required this.valueTypeMigration,
    required this.collectionConfig,
    required this.galleryCoverSources,
    required this.openPresentation,
    required this.stateLoader,
    required this.computedStore,
    required this.managementStore,
    required this.graphStore,
    required this.viewStore,
    required this.boardMoveService,
  });

  /// Production composition boundary used by `GenericDatabasePage`.
  ///
  /// The Widget provides its workspace boundary instead of reaching through it
  /// to the database or adding a new dependency on the legacy Bookmark layer.
  factory GenericDatabasePageServices.fromWorkspaceStore({
    required WorkspaceStore workspaceStore,
    PhotoStorageService photoStorage = const PhotoStorageService(),
    WeblinkMetadataFetch? weblinkMetadataFetch,
    WeblinkPreviewImageIngest? weblinkPreviewImageIngest,
  }) {
    final genericStore = GenericDatabaseStore(workspaceStore.database);
    final objectStore = ObjectStore(genericStore);
    return GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
      photoStorage: photoStorage,
      weblinkMetadataFetch: weblinkMetadataFetch,
      weblinkPreviewImageIngest: weblinkPreviewImageIngest,
    );
  }

  /// Lower-level factory retained for focused Store/Service integration tests.
  factory GenericDatabasePageServices.fromStores({
    required GenericDatabaseStore genericStore,
    required ObjectStore objectStore,
    PhotoStorageService photoStorage = const PhotoStorageService(),
    WeblinkMetadataFetch? weblinkMetadataFetch,
    WeblinkPreviewImageIngest? weblinkPreviewImageIngest,
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
    final systemObjects = SystemObjectStore(
      database: genericStore.database,
      objectStore: objectStore,
    );
    final relationMutations = _GenericDatabaseRelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
      systemObjects: systemObjects,
      photoStorage: photoStorage,
      imageDeletionPolicy: ImageManagedFileDeletionPolicy(
        database: genericStore.database,
        objectStore: objectStore,
        photoStorage: photoStorage,
      ),
    );
    final viewStore = DatabaseViewStore(genericStore.database);
    final propertyAuthoring = DatabasePropertyAuthoringService(objectStore);
    final propertySchema = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: viewStore,
    );
    final relationSchemaEvolution = RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
      relationMutations: relationMutations,
    );
    final valueTypeConversion =
        DatabaseViewPropertyTypeConversionService(objectStore);
    final valueTypeMigration = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final identitySearch = ObjectIdentitySearchService(
      objectStore: objectStore,
      aliasStore: ObjectAliasStore(genericStore),
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
    final previewPipeline = weblinkPreviewImageIngest == null
        ? WeblinkPreviewImagePipeline(
            database: genericStore.database,
            objectStore: objectStore,
            systemObjectStore: systemObjects,
            remoteStorage: RemoteImageStorageService(storage: photoStorage),
          )
        : null;
    final weblinkEnrichment = WeblinkCreateEnrichmentService(
      weblinks: weblinks,
      metadataFetch:
          weblinkMetadataFetch ?? const BookmarkMetadataService().fetch,
      previewImageIngest:
          weblinkPreviewImageIngest ?? previewPipeline!.ingestIfMissing,
    );
    final creator = GenericDatabaseObjectCreateService(
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
      weblinkCreateEnricher: weblinkEnrichment.enrich,
    );
    final computedStore = ObjectComputedValueStore(objectStore);

    return GenericDatabasePageServices(
      genericStore: genericStore,
      objectStore: objectStore,
      loader: loader,
      creator: creator,
      imageImport: GenericDatabaseImageImportService(
        photoStorage: photoStorage,
        objectCreate: creator,
      ),
      relationEditor: ObjectRelationEditorService(
        targets: RelationTargetService(objectStore),
        mutations: relationMutations,
        identitySearch: identitySearch,
      ),
      relationMutations: relationMutations,
      propertyAuthoring: propertyAuthoring,
      propertySchema: propertySchema,
      relationSchemaEvolution: relationSchemaEvolution,
      valueTypeConversion: valueTypeConversion,
      valueTypeMigration: valueTypeMigration,
      collectionConfig: DatabaseCollectionConfigService(
        collectionStore: collectionStore,
        objectStore: objectStore,
      ),
      galleryCoverSources: DatabaseViewGalleryCoverSourceService(
        objectStore: objectStore,
        systemObjects: systemObjects,
      ),
      openPresentation: ObjectOpenPresentationService(
        viewOpenModes: DatabaseViewOpenModeService(viewStore),
        objectTypeDefaults: defaultsStore,
      ),
      stateLoader: GenericDatabasePageStateLoader(
        pageLoader: loader,
        genericStore: genericStore,
        computedStore: computedStore,
        createModeForObjectType: creator.createModeForObjectType,
      ),
      computedStore: computedStore,
      managementStore: ObjectTypeManagementStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      graphStore: ObjectGraphQueryStore(genericStore),
      viewStore: viewStore,
      boardMoveService: ObjectBoardMoveService(
        objectStore,
        relationMutations: relationMutations,
      ),
    );
  }

  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final GenericDatabaseCollectionPageLoader loader;
  final GenericDatabaseObjectCreateService creator;
  final GenericDatabaseImageImportService imageImport;
  final ObjectRelationEditorService relationEditor;
  final RelationMutationService relationMutations;
  final DatabasePropertyAuthoringService propertyAuthoring;
  final DatabaseViewPropertySchemaService propertySchema;
  final RelationSchemaEvolutionService relationSchemaEvolution;
  final DatabaseViewPropertyTypeConversionService valueTypeConversion;
  final DatabaseViewPropertyTypeMigrationService valueTypeMigration;
  final DatabaseCollectionConfigService collectionConfig;
  final DatabaseViewGalleryCoverSourceService galleryCoverSources;
  final ObjectOpenPresentationService openPresentation;
  final GenericDatabasePageStateLoader stateLoader;
  final ObjectComputedValueStore computedStore;
  final ObjectTypeManagementStore managementStore;
  final ObjectGraphQueryStore graphStore;
  final DatabaseViewStore viewStore;
  final ObjectBoardMoveService boardMoveService;
}

/// Stable user-facing boundary when a generic Images host tries to delete an
/// Image still participating in the legacy Photo compatibility lifecycle.
class LegacyPhotoCompatibilityImageDeletionException implements Exception {
  const LegacyPhotoCompatibilityImageDeletionException();

  @override
  String toString() =>
      'この画像は従来の写真との互換同期で使用されています。写真管理から削除してください。';
}

/// Keeps the generic page's existing Relation-safe Object deletion API while
/// layering Object-owned managed-Image file cleanup at the composition boundary.
/// Relation semantics stay delegated to [RelationMutationService].
class _GenericDatabaseRelationMutationService extends RelationMutationService {
  _GenericDatabaseRelationMutationService({
    required ObjectStore objectStore,
    required BidirectionalRelationStore bidirectionalStore,
    required GenericDatabaseStore genericStore,
    required this.systemObjects,
    required this.photoStorage,
    required this.imageDeletionPolicy,
  }) : super(
          objectStore: objectStore,
          bidirectionalStore: bidirectionalStore,
          genericStore: genericStore,
        );

  final SystemObjectStore systemObjects;
  final PhotoStorageService photoStorage;
  final ImageManagedFileDeletionPolicy imageDeletionPolicy;

  @override
  Future<void> deleteObject({
    required int workspaceId,
    required int objectTypeId,
    required int objectId,
  }) async {
    await _ensureImageDeletionAllowed(
      workspaceId: workspaceId,
      objectTypeId: objectTypeId,
      objectId: objectId,
    );

    String? managedFileToDelete;
    try {
      managedFileToDelete = await _managedImageCleanupCandidate(
        workspaceId: workspaceId,
        objectTypeId: objectTypeId,
        objectId: objectId,
      );
    } catch (_) {
      // File ownership is an optional destructive-cleanup audit. Never make an
      // otherwise valid Object deletion fail because ownership cannot be proven.
      managedFileToDelete = null;
    }

    await super.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: objectTypeId,
      objectId: objectId,
    );

    if (managedFileToDelete == null) return;
    try {
      await photoStorage.deleteManagedPhoto(managedFileToDelete);
    } catch (_, stackTrace) {
      // The canonical Object is already deleted successfully. A secondary file
      // cleanup failure must not turn that completed deletion into a UI error.
      assert(() {
        developer.log(
          'Managed Image file cleanup failed after Object deletion.',
          name: 'bookmark_app.generic_database_delete',
          stackTrace: stackTrace,
        );
        return true;
      }());
    }
  }

  Future<void> _ensureImageDeletionAllowed({
    required int workspaceId,
    required int objectTypeId,
    required int objectId,
  }) async {
    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null || objectType.workspaceId != workspaceId) return;
    final systemKey = await systemObjects.systemKeyForObjectType(objectTypeId);
    if (systemKey != ImageObjectService.systemKey) return;

    if (await _isActiveLegacyPhotoTarget(
      workspaceId: workspaceId,
      objectId: objectId,
    )) {
      throw const LegacyPhotoCompatibilityImageDeletionException();
    }

    final legacyIdProperties = objectType.properties
        .where((property) => property.name == 'Legacy Photo ID')
        .toList(growable: false);
    if (legacyIdProperties.length > 1) {
      throw const LegacyPhotoCompatibilityImageDeletionException();
    }
    if (legacyIdProperties.isEmpty) return;

    final objects = await objectStore.listObjects(objectTypeId);
    for (final object in objects) {
      if (object.id != objectId) continue;
      if (object.values[legacyIdProperties.single.id] != null) {
        throw const LegacyPhotoCompatibilityImageDeletionException();
      }
      return;
    }
  }

  Future<bool> _isActiveLegacyPhotoTarget({
    required int workspaceId,
    required int objectId,
  }) async {
    try {
      final table = await systemObjects.database.customSelect(
        '''SELECT 1 AS present
           FROM sqlite_master
           WHERE type = 'table' AND name = ?
           LIMIT 1''',
        variables: const [Variable<String>('photo_object_links')],
      ).getSingleOrNull();
      if (table == null) return false;

      final mapping = await systemObjects.database.customSelect(
        '''SELECT 1 AS present
           FROM photo_object_links
           WHERE workspace_id = ? AND object_id = ?
           LIMIT 1''',
        variables: [Variable<int>(workspaceId), Variable<int>(objectId)],
      ).getSingleOrNull();
      return mapping != null;
    } catch (_) {
      // This audit protects a destructive user action. If compatibility
      // ownership cannot be read safely, retain the Image and expose the same
      // stable product boundary rather than leaking a database exception.
      return true;
    }
  }

  Future<String?> _managedImageCleanupCandidate({
    required int workspaceId,
    required int objectTypeId,
    required int objectId,
  }) async {
    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null || objectType.workspaceId != workspaceId) return null;
    final systemKey = await systemObjects.systemKeyForObjectType(objectTypeId);
    if (systemKey != ImageObjectService.systemKey) return null;

    final fileProperties = objectType.properties
        .where((property) => property.name == 'File')
        .toList(growable: false);
    if (fileProperties.length != 1) return null;
    final objects = await objectStore.listObjects(objectTypeId);
    for (final object in objects) {
      if (object.id != objectId) continue;
      final filePath = '${object.values[fileProperties.single.id] ?? ''}'.trim();
      if (filePath.isEmpty) return null;
      return imageDeletionPolicy.deletableManagedPath(
        deletingObjectId: objectId,
        filePath: filePath,
      );
    }
    return null;
  }
}
