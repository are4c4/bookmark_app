import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../data/app_database.dart';
import '../data/bookmark_weblink_object_bridge.dart';
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
    bookmarkWeblinkBridge = BookmarkWeblinkObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
    );
  }

  /// Only one profile/workspace is active in the app at a time. Keeping the
  /// active mirror here lets short-lived bootstrap calls safely replace the
  /// previous listener without forcing repositories to own migration state.
  static ObjectSyncService? _activeService;

  final AppDatabase database;
  final ObjectStore objectStore;
  late final SystemObjectStore systemObjectStore;
  late final TagObjectBridge tagBridge;
  late final CoreObjectBridge coreBridge;
  late final BookmarkWeblinkObjectBridge bookmarkWeblinkBridge;

  StreamSubscription<Object?>? _subscription;
  int? _watchedWorkspaceId;
  bool _syncing = false;
  bool _syncQueued = false;
  bool _disposed = false;

  /// Activates a live Object mirror for [workspaceId].
  ///
  /// Calling this from startup or Workspace switching automatically disposes
  /// the previous active mirror and then performs an immediate sync.
  Future<void> syncWorkspace(int workspaceId) => startWatchingWorkspace(workspaceId);

  Future<void> syncActiveWorkspace() async {
    final workspaceId = await WorkspaceStore(database).activeWorkspaceId();
    if (workspaceId != null) await startWatchingWorkspace(workspaceId);
  }

  Future<void> startWatchingWorkspace(int workspaceId) async {
    if (_disposed) return;

    final previous = _activeService;
    if (previous != null && previous != this) {
      await previous.dispose();
    }
    _activeService = this;

    if (_watchedWorkspaceId == workspaceId && _subscription != null) {
      await _syncNow(workspaceId);
      return;
    }

    await stopWatching();
    if (_disposed) return;
    _watchedWorkspaceId = workspaceId;
    await _syncNow(workspaceId);

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

  Future<void> _syncNow(int workspaceId) async {
    await coreBridge.syncAll(workspaceId);
    await bookmarkWeblinkBridge.syncWorkspace(workspaceId);
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
        await _syncNow(workspaceId);
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
    if (identical(_activeService, this)) {
      _activeService = null;
    }
    await stopWatching();
  }
}
