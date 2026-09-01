import 'dart:async';

import 'package:rxdart/rxdart.dart';

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

  StreamSubscription<Object?>? _subscription;
  int? _watchedWorkspaceId;
  bool _syncing = false;
  bool _syncQueued = false;
  bool _disposed = false;

  Future<void> syncWorkspace(int workspaceId) => coreBridge.syncAll(workspaceId);

  Future<void> syncActiveWorkspace() async {
    final workspaceId = await WorkspaceStore(database).activeWorkspaceId();
    if (workspaceId != null) await syncWorkspace(workspaceId);
  }

  /// Keeps the Object mirror current while the app is open.
  ///
  /// Legacy bookmark/tag/photo tables remain authoritative during migration.
  /// Changes to them are debounced and mirrored into the active Workspace's
  /// system ObjectTypes. Object writes do not feed these streams, so this does
  /// not create a synchronization loop.
  Future<void> startWatchingWorkspace(int workspaceId) async {
    if (_disposed) return;
    if (_watchedWorkspaceId == workspaceId && _subscription != null) return;

    await stopWatching();
    _watchedWorkspaceId = workspaceId;
    await syncWorkspace(workspaceId);

    final workspaceStore = WorkspaceStore(database);
    final changes = Rx.merge<Object?>([
      database.watchAllTags().map<Object?>((_) => null),
      database.watchAllPhotos().map<Object?>((_) => null),
      database.watchBookmarkItems().map<Object?>((_) => null),
      workspaceStore.watchBookmarkIds(workspaceId).map<Object?>((_) => null),
    ]).debounceTime(const Duration(milliseconds: 250));

    _subscription = changes.listen((_) {
      if (_disposed || _watchedWorkspaceId != workspaceId) return;
      _queueSync(workspaceId);
    });
  }

  void _queueSync(int workspaceId) {
    if (_syncing) {
      _syncQueued = true;
      return;
    }
    unawaited(_runQueuedSync(workspaceId));
  }

  Future<void> _runQueuedSync(int workspaceId) async {
    if (_disposed || _watchedWorkspaceId != workspaceId) return;
    _syncing = true;
    try {
      do {
        _syncQueued = false;
        await syncWorkspace(workspaceId);
      } while (_syncQueued && !_disposed && _watchedWorkspaceId == workspaceId);
    } finally {
      _syncing = false;
    }
  }

  Future<void> stopWatching() async {
    _watchedWorkspaceId = null;
    _syncQueued = false;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopWatching();
  }
}
