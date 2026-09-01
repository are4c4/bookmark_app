import '../data/app_database.dart';
import '../data/core_object_bridge.dart';
import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../data/system_object_store.dart';
import '../data/tag_object_bridge.dart';
import '../data/workspace_store.dart';

class ObjectSyncService {
  ObjectSyncService(this.database)
      : objectStore = ObjectStore(GenericDatabaseStore(database)) {
    systemObjectStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    tagBridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
    );
    coreBridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
      tagBridge: tagBridge,
    );
  }

  final AppDatabase database;
  final ObjectStore objectStore;
  late final SystemObjectStore systemObjectStore;
  late final TagObjectBridge tagBridge;
  late final CoreObjectBridge coreBridge;

  Future<void> syncWorkspace(int workspaceId) => coreBridge.syncAll(workspaceId);

  Future<void> syncActiveWorkspace() async {
    final workspaceId = await WorkspaceStore(database).activeWorkspaceId();
    if (workspaceId != null) await syncWorkspace(workspaceId);
  }
}
