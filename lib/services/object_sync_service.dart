import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';

import '../data/app_database.dart';
import '../data/bookmark_read_store.dart';
import '../data/bookmark_weblink_object_bridge.dart';
import '../data/core_object_bridge.dart';
import '../data/daily_note_service.dart';
import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../data/object_type_defaults_store.dart';
import '../data/photo_read_store.dart';
import '../data/relation_read_service.dart';
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

  /// Optional composition callback invoked only after preview ingestion has
  /// durably created/reused an Image and verified the canonical Representative
  /// Image Relation. The sync service reports only canonical mutation impact;
  /// it does not know whether a caller uses Search, analytics, or no consumer.
  final Future<void> Function(int imageObjectId)? _onPreviewImageIngested;

  /// Optional composition callback for a completed live legacy -> canonical
  /// mirror pass. The ids are invalidation metadata only: current mapped
  /// Tag/Image/Bookmark Objects, canonical Bookmark Weblink targets, plus ids
  /// remembered from the preceding pass so deleted mirror rows can be cleared.
  ///
  /// Initial bootstrap/workspace activation records the baseline without
  /// notifying. Later watcher-driven or explicit same-workspace syncs notify
  /// only after canonical mutation has succeeded. Callback failure is isolated
  /// from the already-committed Object sync.
  final Future<void> Function(Iterable<int> objectIds)?
      _onCanonicalObjectsMirrored;

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
  Set<int>? _lastCanonicalMirrorObjectIds;
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
    await coreBridge.syncAll(workspaceId);
    await bookmarkWeblinkBridge.syncWorkspace(workspaceId);

    // Daily Notes are a normal system ObjectType and should be available to the
    // generic sidebar/Database host even before the user opens the first note.
    final genericStore = GenericDatabaseStore(database);
    await DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: systemObjectStore,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    ).ensureDefinition(workspaceId);

    await _recordCanonicalSyncImpact(
      workspaceId,
      notify: notifyCanonicalImpact,
    );

    if (enableRemotePreviewImages) {
      // Remote enrichment must never hold up the canonical Object mirror or app
      // startup. The queue below coalesces later syncs and contains failures.
      unawaited(syncRemotePreviewImages(workspaceId));
    }
  }

  Future<void> _recordCanonicalSyncImpact(
    int workspaceId, {
    required bool notify,
  }) async {
    Set<int> current;
    try {
      current = await _collectCanonicalMirrorObjectIds(workspaceId);
    } catch (_, stackTrace) {
      // Impact reporting is a derived notification seam. Never make a healthy
      // canonical mirror fail because optional downstream invalidation metadata
      // could not be collected. Keep the previous baseline for a later retry.
      _debugCanonicalImpactFailure('collection', stackTrace);
      return;
    }

    final previous = _lastCanonicalMirrorObjectIds;
    _lastCanonicalMirrorObjectIds = Set<int>.unmodifiable(current);
    final callback = _onCanonicalObjectsMirrored;
    if (!notify || callback == null) return;

    final affected = <int>{
      ...?previous,
      ...current,
    };
    if (affected.isEmpty) return;
    final ordered = affected.toList()..sort();
    try {
      await callback(List<int>.unmodifiable(ordered));
    } catch (_, stackTrace) {
      // Canonical mirror mutation has already succeeded. Search/projection
      // refresh is rebuildable and must not make the watcher retry or roll back
      // legacy/Object authority. Do not include ids or user content in logs.
      _debugCanonicalImpactFailure('notification', stackTrace);
    }
  }

  Future<Set<int>> _collectCanonicalMirrorObjectIds(int workspaceId) async {
    final result = <int>{};
    List<int> bookmarkObjectIds = const <int>[];
    for (final table in const <String>[
      'tag_object_links',
      'photo_object_links',
      'bookmark_object_links',
    ]) {
      final rows = await database.customSelect(
        'SELECT object_id FROM $table WHERE workspace_id = ? ORDER BY object_id',
        variables: <Variable<Object>>[Variable<int>(workspaceId)],
      ).get();
      final ids = rows
          .map((row) => row.read<int>('object_id'))
          .toList(growable: false);
      result.addAll(ids);
      if (table == 'bookmark_object_links') bookmarkObjectIds = ids;
    }

    if (bookmarkObjectIds.isEmpty) return result;
    final bookmarkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    );
    if (bookmarkType == null) return result;
    final weblinkRelations = bookmarkType.properties
        .where(
          (property) =>
              property.name == BookmarkWeblinkObjectBridge.relationName &&
              property.isRelation,
        )
        .toList(growable: false);
    if (weblinkRelations.length != 1) return result;

    final relationId = weblinkRelations.single.id;
    final relationReads = RelationReadService(objectStore);
    for (final bookmarkObjectId in bookmarkObjectIds) {
      try {
        final outgoing = await relationReads.outgoing(
          sourceObjectTypeId: bookmarkType.id,
          sourceObjectId: bookmarkObjectId,
        );
        for (final relation in outgoing) {
          if (relation.property.id == relationId) {
            result.add(relation.targetObject.id);
          }
        }
      } on FormatException {
        // Relation owns persisted/index/schema trust. Corrupt optional relation
        // state contributes no target invalidation instead of becoming a second
        // raw-edge authority inside Object sync.
      }
    }
    return result;
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
    _lastCanonicalMirrorObjectIds = null;
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
