import '../database/database_definition.dart';
import 'database_view_gallery_adapter.dart';
import 'database_view_store.dart';
import 'generic_database_store.dart';
import 'image_object_service.dart';
import 'object_store.dart';
import 'system_object_store.dart';
import 'weblink_object_service.dart';

/// Seeds the first persisted View for generic Database hosts without taking
/// ownership away from user-created View configuration.
///
/// System collections may choose a more useful first-run presentation through
/// ordinary [DatabaseViewConfig] settings. Once any View exists for the
/// Database key, this service returns it unchanged and never reapplies defaults.
class DatabaseViewDefaultProvisioningService {
  const DatabaseViewDefaultProvisioningService({
    required this.viewStore,
    required this.systemObjects,
  });

  factory DatabaseViewDefaultProvisioningService.fromViewStore(
    DatabaseViewStore viewStore,
  ) {
    final genericStore = GenericDatabaseStore(viewStore.database);
    return DatabaseViewDefaultProvisioningService(
      viewStore: viewStore,
      systemObjects: SystemObjectStore(
        database: viewStore.database,
        objectStore: ObjectStore(genericStore),
      ),
    );
  }

  final DatabaseViewStore viewStore;
  final SystemObjectStore systemObjects;

  Future<DatabaseViewConfig> ensureDefaultView({
    required int workspaceId,
    required DatabaseDefinition definition,
    int? objectTypeId,
  }) async {
    final existing = await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    if (existing.isNotEmpty) return existing.first;

    final resolvedObjectTypeId = objectTypeId ?? _objectTypeId(definition.key);
    final objectType = resolvedObjectTypeId == null
        ? null
        : await systemObjects.objectStore.getObjectType(resolvedObjectTypeId);
    final systemKey = objectType != null &&
            objectType.workspaceId == workspaceId &&
            resolvedObjectTypeId != null
        ? await systemObjects.systemKeyForObjectType(resolvedObjectTypeId)
        : null;

    if (systemKey == ImageObjectService.systemKey) {
      return _createAndRead(
        workspaceId: workspaceId,
        definition: definition,
        name: 'ギャラリー',
        layoutType: 'gallery',
        settings: <String, dynamic>{
          DatabaseViewGalleryAdapter.settingsKey:
              GalleryViewMode.masonry.storageValue,
          DatabaseViewGalleryAdapter.coverSourceSettingsKey:
              const GalleryCoverSource.directImage().toStorage(),
        },
      );
    }

    if (systemKey == WeblinkObjectService.systemKey) {
      return _createAndRead(
        workspaceId: workspaceId,
        definition: definition,
        name: 'リスト',
        layoutType: 'list',
      );
    }

    return viewStore.ensureDefaultView(
      workspaceId: workspaceId,
      definition: definition,
    );
  }

  Future<DatabaseViewConfig> _createAndRead({
    required int workspaceId,
    required DatabaseDefinition definition,
    required String name,
    required String layoutType,
    Map<String, dynamic> settings = const <String, dynamic>{},
  }) async {
    final id = await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: name,
      layoutType: layoutType,
      settings: settings,
    );
    final views = await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    return views.firstWhere((view) => view.id == id);
  }

  int? _objectTypeId(String databaseKey) {
    const prefix = 'custom:';
    if (!databaseKey.startsWith(prefix)) return null;
    final id = int.tryParse(databaseKey.substring(prefix.length));
    return id != null && id > 0 ? id : null;
  }
}
