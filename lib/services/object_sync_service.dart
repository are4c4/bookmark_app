import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../data/app_database.dart';
import '../data/bookmark_weblink_object_bridge.dart';
import '../data/core_object_bridge.dart';
import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../data/object_type_defaults_store.dart';
import '../data/system_object_store.dart';
import '../data/tag_object_bridge.dart';
import '../data/weblink_object_service.dart';
import '../data/workspace_store.dart';
import 'remote_image_storage_service.dart';
import 'weblink_preview_image_pipeline.dart';

class ObjectSyncService {
  ObjectSyncService(
    this.database, {
    this.enableRemotePreviewImages = false,
    RemoteImageStorageService? remoteImageStorage,
  })  : objectStore = ObjectStore(GenericDatabaseStore(database)),
        _remoteImageStorage = remoteImageStorage {
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
  final bool enableRemotePreviewImages;
  final RemoteImageStorageService? _remoteImageStorage;
  late final SystemObjectStore systemObjectStore;
  late final TagObjectBridge tagBridge;
  late final CoreObjectBridge coreBridge;
  late final BookmarkWeblinkObjectBridge bookmarkWeblinkBridge;
  late final WeblinkPreviewImagePipeline _previewImagePipeline =
      WeblinkPreviewImagePipeline(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjectStore,
        remoteStorage: _remoteImageStorage,
      );

  final Map<String, String> _attemptedPreviewUrls = <String, String>{};
  StreamSubscription<Object?>? _subscription;
  Future<void>? _previewSyncFuture;
  int? _queuedPreviewWorkspaceId;
  int? _watchedWorkspaceId;
  bool _syncing = false;
  bool _syncQueued = false;
  bool _disposed = false;

  /// Activates a live Object mirror for [workspaceId].
  ///
  /// Calling this from startup or Workspace switching automatically disposes
  /// the previous active mirror and then performs an immediate sync.
  Future<void> syncWorkspace(int workspaceId) =>
      startWatchingWorkspace(workspaceId);

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
    if (enableRemotePreviewImages) {
      // Remote enrichment must never hold up the canonical Object mirror or app
      // startup. The queue below coalesces later syncs and contains failures.
      unawaited(syncRemotePreviewImages(workspaceId));
    }
  }

  /// Runs the optional Weblink preview ingestion queue and can be awaited by
  /// focused callers/tests that need to observe managed-image completion.
  Future<void> syncRemotePreviewImages(int workspaceId) {
    if (!enableRemotePreviewImages || _disposed) return Future<void>.value();
    _queuedPreviewWorkspaceId = workspaceId;
    final running = _previewSyncFuture;
    if (running != null) return running;
    final future = _runQueuedPreviewSync();
    _previewSyncFuture = future;
    return future;
  }

  Future<void> _runQueuedPreviewSync() async {
    try {
      while (!_disposed) {
        final workspaceId = _queuedPreviewWorkspaceId;
        if (workspaceId == null) return;
        _queuedPreviewWorkspaceId = null;
        await _performPreviewSync(workspaceId);
      }
    } finally {
      _previewSyncFuture = null;
    }
  }

  Future<void> _performPreviewSync(int workspaceId) async {
    if (_disposed || _watchedWorkspaceId != workspaceId) return;
    try {
      final genericStore = GenericDatabaseStore(database);
      final weblinks = WeblinkObjectService(
        systemObjects: systemObjectStore,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );
      final definition = await weblinks.ensureDefinition(workspaceId);
      final objects = await objectStore.listObjects(definition.objectType.id);

      for (final weblink in objects) {
        if (_disposed || _watchedWorkspaceId != workspaceId) return;
        final rawPreview =
            '${weblink.values[definition.previewImageUrlProperty.id] ?? ''}'
                .trim();
        if (rawPreview.isEmpty) continue;

        String normalizedPreview;
        try {
          normalizedPreview = weblinks.normalizeUrl(rawPreview);
        } on ArgumentError {
          continue;
        }
        final attemptKey = '$workspaceId:${weblink.id}';
        if (_attemptedPreviewUrls[attemptKey] == normalizedPreview) continue;
        // Record before I/O so a failing remote URL cannot be retried on every
        // tag/photo/bookmark watcher tick. A changed URL or app restart retries.
        _attemptedPreviewUrls[attemptKey] = normalizedPreview;

        try {
          await _previewImagePipeline.ingestIfMissing(
            workspaceId: workspaceId,
            weblinkObjectId: weblink.id,
          );
        } catch (_) {
          // Thumbnail ingestion is optional. Canonical Bookmark -> Weblink sync
          // remains successful even if remote I/O or Image enrichment fails.
        }
      }
    } catch (_) {
      // Schema/setup enrichment failures are contained for the same reason.
    }
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
    _queuedPreviewWorkspaceId = null;
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
