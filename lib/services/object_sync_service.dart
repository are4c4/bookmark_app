import 'dart:async';
import 'dart:io';

import 'package:rxdart/rxdart.dart';

import '../data/app_database.dart';
import '../data/bookmark_read_store.dart';
import '../data/bookmark_weblink_object_bridge.dart';
import '../data/bookmark_weblink_tag_convergence_service.dart';
import '../data/core_object_bridge.dart';
import '../data/daily_note_service.dart';
import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../data/object_type_defaults_store.dart';
import '../data/person_object_bridge.dart';
import '../data/photo_read_store.dart';
import '../data/system_object_store.dart';
import '../data/tag_object_bridge.dart';
import '../data/weblink_object_service.dart';
import '../data/workspace_store.dart';
import 'object_sync_impact.dart';
import 'person_profile_image_relation_service.dart';
import 'remote_image_storage_service.dart';
import 'weblink_preview_image_pipeline.dart';

class ObjectSyncService {
  ObjectSyncService(
    this.database, {
    this.enableRemotePreviewImages = false,
    RemoteImageStorageService? remoteImageStorage,
    Future<void> Function(int imageObjectId)? onPreviewImageIngested,
    Future<void> Function(Iterable<int> objectIds)? onCanonicalObjectsMirrored,
  })  : _remoteImageStorage = remoteImageStorage,
        _onPreviewImageIngested = onPreviewImageIngested,
        _onCanonicalObjectsMirrored = onCanonicalObjectsMirrored,
        objectStore = ObjectStore(GenericDatabaseStore(database)) {
    systemObjectStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    tagBridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
    );
    personBridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
    );
    personProfileImages = PersonProfileImageRelationService(database);
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
    bookmarkWeblinkTags = BookmarkWeblinkTagConvergenceService(
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

  /// Optional composition callback invoked only after preview ingestion has
  /// durably created/reused an Image and verified the canonical Representative
  /// Image Relation. The sync service reports only canonical mutation impact;
  /// it does not know whether a caller uses Search, analytics, or no consumer.
  final Future<void> Function(int imageObjectId)? _onPreviewImageIngested;

  /// Optional composition callback for canonical Objects whose persisted
  /// semantic state actually changed during one successful live mirror pass.
  ///
  /// Initial bootstrap/workspace activation does not notify. Later
  /// watcher-driven or explicit same-workspace syncs notify only the exact
  /// changed canonical ids after every bridge has completed. Callback failure
  /// is isolated from the already-committed Object sync.
  final Future<void> Function(Iterable<int> objectIds)?
      _onCanonicalObjectsMirrored;

  late final SystemObjectStore systemObjectStore;
  late final TagObjectBridge tagBridge;
  late final PersonObjectBridge personBridge;
  late final PersonProfileImageRelationService personProfileImages;
  late final CoreObjectBridge coreBridge;
  late final BookmarkWeblinkObjectBridge bookmarkWeblinkBridge;
  late final BookmarkWeblinkTagConvergenceService bookmarkWeblinkTags;
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

  static void _debugPreviewFailure(String stage, StackTrace stackTrace) {
    assert(() {
      stderr.writeln(
        'ObjectSyncService: optional remote preview $stage failed; canonical sync continues.',
      );
      stderr.writeln(stackTrace);
      return true;
    }());
  }

  static void _debugCanonicalImpactFailure(
    String stage,
    StackTrace stackTrace,
  ) {
    assert(() {
      stderr.writeln(
        'ObjectSyncService: optional canonical sync impact $stage failed; canonical sync continues.',
      );
      stderr.writeln(stackTrace);
      return true;
    }());
  }

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
      await _syncNow(workspaceId, notifyCanonicalImpact: true);
      return;
    }

    await stopWatching();
    if (_disposed) return;
    _watchedWorkspaceId = workspaceId;
    await _syncNow(workspaceId);

    final workspaceStore = WorkspaceStore(database);
    final changes = Rx.merge<Object?>([
      database.watchAllTags().map<Object?>((_) => null),
      database.watchAllPeople().map<Object?>((_) => null),
      PhotoReadStore(database).watchAll().map<Object?>((_) => null),
      BookmarkReadStore(database).watchItems().map<Object?>((_) => null),
      workspaceStore.watchBookmarkIds(workspaceId).map<Object?>((_) => null),
    ]).debounceTime(const Duration(milliseconds: 250));

    _subscription = changes.listen((_) {
      if (_disposed || _watchedWorkspaceId != workspaceId) return;
      _queueSync(workspaceId);
    });
  }

  Future<void> _syncNow(
    int workspaceId, {
    bool notifyCanonicalImpact = false,
  }) async {
    final before = await ObjectSyncSemanticSnapshot.capture(
      objectStore: objectStore,
      systemObjects: systemObjectStore,
      workspaceId: workspaceId,
      systemKeys: objectSyncMirrorSystemKeys,
    );
    final previousBookmarkTagSource = await bookmarkWeblinkTags
        .captureSourceSnapshot(workspaceId);

    final personObjectIds = await personBridge.syncLegacyPeople(workspaceId);
    final coreImpact = await coreBridge.syncAllWithImpact(workspaceId);
    // Photo promotion runs in CoreObjectBridge. Only after those stable
    // photo_object_links exist can legacy Person profile photos be projected to
    // the canonical single Profile Image Relation without inventing identities.
    await personProfileImages.migrateLegacyProfilePhotos(workspaceId);
    final weblinkSync =
        await bookmarkWeblinkBridge.syncWorkspaceWithImpact(workspaceId);
    final tagConvergence = await bookmarkWeblinkTags.reconcileAfterWeblinkSync(
      workspaceId,
      previousSource: previousBookmarkTagSource,
    );

    // Daily Notes are a normal system ObjectType and should be available to the
    // generic sidebar/Database host even before the user opens the first note.
    final genericStore = GenericDatabaseStore(database);
    await DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: systemObjectStore,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    ).ensureDefinition(workspaceId);

    final bridgeCandidates = ObjectSyncImpact(personObjectIds)
        .combine(coreImpact)
        .combine(weblinkSync.impact)
        .combine(ObjectSyncImpact(tagConvergence.mutatedWeblinkObjectIds));
    final after = await ObjectSyncSemanticSnapshot.capture(
      objectStore: objectStore,
      systemObjects: systemObjectStore,
      workspaceId: workspaceId,
      systemKeys: objectSyncMirrorSystemKeys,
    );
    final exactImpact = before.changesTo(
      after,
      candidates: bridgeCandidates.objectIds,
    );
    await _notifyCanonicalSyncImpact(
      exactImpact,
      notify: notifyCanonicalImpact,
    );

    if (enableRemotePreviewImages) {
      // Remote enrichment must never hold up the canonical Object mirror or app
      // startup. The queue below coalesces later syncs and contains failures.
      unawaited(syncRemotePreviewImages(workspaceId));
    }
  }

  Future<void> _notifyCanonicalSyncImpact(
    ObjectSyncImpact impact, {
    required bool notify,
  }) async {
    final callback = _onCanonicalObjectsMirrored;
    if (!notify || callback == null || impact.isEmpty) return;
    try {
      await callback(impact.objectIds);
    } catch (_, stackTrace) {
      // Canonical mirror mutation has already succeeded. Downstream projection
      // refresh is rebuildable and must not make the watcher retry or roll back
      // legacy/Object authority. Do not include ids or user content in logs.
      _debugCanonicalImpactFailure('notification', stackTrace);
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

  Future<void> _notifyPreviewImageIngested(int imageObjectId) async {
    final callback = _onPreviewImageIngested;
    if (callback == null) return;
    try {
      await callback(imageObjectId);
    } catch (_, stackTrace) {
      // Canonical preview ingestion has already succeeded. A downstream
      // projection/notification failure must remain best-effort and must not
      // make Object sync retry the remote URL or undo the Relation mutation.
      // Do not include ids, URLs, paths or exception text in diagnostics.
      _debugPreviewFailure('post-ingestion notification', stackTrace);
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
          final imageObjectId = await _previewImagePipeline.ingestIfMissing(
            workspaceId: workspaceId,
            weblinkObjectId: weblink.id,
          );
          if (imageObjectId != null) {
            await _notifyPreviewImageIngested(imageObjectId);
          }
        } catch (_, stackTrace) {
          // Thumbnail ingestion is optional. Canonical Bookmark -> Weblink sync
          // remains successful even if remote I/O or Image enrichment fails.
          // Do not log URLs, Object ids, exception text or other user content.
          _debugPreviewFailure('image ingestion', stackTrace);
        }
      }
    } catch (_, stackTrace) {
      // Schema/setup enrichment failures are contained for the same reason.
      // Preserve that contract, but make unexpected failures observable in
      // debug/test builds without logging user content.
      _debugPreviewFailure('schema/setup', stackTrace);
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
        await _syncNow(workspaceId, notifyCanonicalImpact: true);
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
