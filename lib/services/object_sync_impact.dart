import 'dart:convert';

import '../data/bookmark_weblink_object_bridge.dart';
import '../data/core_object_bridge.dart';
import '../data/object_store.dart';
import '../data/system_object_store.dart';
import '../data/tag_object_bridge.dart';
import '../data/weblink_object_service.dart';
import '../domain/object_model.dart';

/// Immutable canonical Object ids affected by one successful mirror operation.
///
/// The result intentionally contains no legacy ids or user content so callers
/// can use it as generic invalidation/completion metadata without depending on
/// bridge internals or Search.
class ObjectSyncImpact {
  ObjectSyncImpact(Iterable<int> objectIds)
      : objectIds = List<int>.unmodifiable(
          (objectIds.toSet().toList()..sort()),
        );

  static final empty = ObjectSyncImpact(const <int>[]);

  final List<int> objectIds;

  bool get isEmpty => objectIds.isEmpty;

  ObjectSyncImpact combine(ObjectSyncImpact other) =>
      ObjectSyncImpact(<int>{...objectIds, ...other.objectIds});
}

/// Opaque semantic snapshot used only to remove false-positive impact.
///
/// Timestamps are deliberately excluded: compatibility bridges may revisit a
/// row, but downstream projections only need invalidation when canonical Object
/// title/Value state is observably different after the successful pass.
class ObjectSyncSemanticSnapshot {
  ObjectSyncSemanticSnapshot._(this._fingerprints);

  final Map<int, String> _fingerprints;

  static Future<ObjectSyncSemanticSnapshot> capture({
    required ObjectStore objectStore,
    required SystemObjectStore systemObjects,
    required int workspaceId,
    required Iterable<String> systemKeys,
  }) async {
    final fingerprints = <int, String>{};
    for (final systemKey in systemKeys.toSet()) {
      final type = await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: systemKey,
      );
      if (type == null) continue;
      for (final object in await objectStore.listObjects(type.id)) {
        fingerprints[object.id] = _fingerprint(object);
      }
    }
    return ObjectSyncSemanticSnapshot._(fingerprints);
  }

  ObjectSyncImpact changesTo(
    ObjectSyncSemanticSnapshot after, {
    Iterable<int>? candidates,
  }) {
    final ids = candidates == null
        ? <int>{..._fingerprints.keys, ...after._fingerprints.keys}
        : candidates.toSet();
    final changed = <int>[];
    for (final id in ids) {
      if (_fingerprints[id] != after._fingerprints[id]) changed.add(id);
    }
    return ObjectSyncImpact(changed);
  }

  static String _fingerprint(AppObject object) => jsonEncode(<String, dynamic>{
        'title': object.title,
        'values': _canonicalize(object.values),
      });

  static dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final entries = value.entries
          .map((entry) => MapEntry('${entry.key}', entry.value))
          .toList(growable: false)
        ..sort((a, b) => a.key.compareTo(b.key));
      return <String, dynamic>{
        for (final entry in entries) entry.key: _canonicalize(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}

class BookmarkWeblinkSyncImpactReport {
  const BookmarkWeblinkSyncImpactReport({
    required this.report,
    required this.impact,
  });

  final BookmarkWeblinkSyncReport report;
  final ObjectSyncImpact impact;
}

extension CoreObjectBridgeSyncImpact on CoreObjectBridge {
  Future<ObjectSyncImpact> syncAllWithImpact(int workspaceId) async {
    final before = await ObjectSyncSemanticSnapshot.capture(
      objectStore: objectStore,
      systemObjects: systemObjectStore,
      workspaceId: workspaceId,
      systemKeys: const <String>[
        TagObjectBridge.systemKey,
        CoreObjectBridge.photoSystemKey,
        CoreObjectBridge.bookmarkSystemKey,
      ],
    );
    await syncAll(workspaceId);
    final after = await ObjectSyncSemanticSnapshot.capture(
      objectStore: objectStore,
      systemObjects: systemObjectStore,
      workspaceId: workspaceId,
      systemKeys: const <String>[
        TagObjectBridge.systemKey,
        CoreObjectBridge.photoSystemKey,
        CoreObjectBridge.bookmarkSystemKey,
      ],
    );
    return before.changesTo(after);
  }
}

extension BookmarkWeblinkObjectBridgeSyncImpact on BookmarkWeblinkObjectBridge {
  Future<BookmarkWeblinkSyncImpactReport> syncWorkspaceWithImpact(
    int workspaceId,
  ) async {
    final before = await ObjectSyncSemanticSnapshot.capture(
      objectStore: objectStore,
      systemObjects: systemObjectStore,
      workspaceId: workspaceId,
      systemKeys: const <String>[
        BookmarkWeblinkObjectBridge.bookmarkSystemKey,
        WeblinkObjectService.systemKey,
      ],
    );
    final report = await syncWorkspace(workspaceId);
    final after = await ObjectSyncSemanticSnapshot.capture(
      objectStore: objectStore,
      systemObjects: systemObjectStore,
      workspaceId: workspaceId,
      systemKeys: const <String>[
        BookmarkWeblinkObjectBridge.bookmarkSystemKey,
        WeblinkObjectService.systemKey,
      ],
    );
    return BookmarkWeblinkSyncImpactReport(
      report: report,
      impact: before.changesTo(after),
    );
  }
}

const objectSyncMirrorSystemKeys = <String>[
  TagObjectBridge.systemKey,
  CoreObjectBridge.photoSystemKey,
  CoreObjectBridge.bookmarkSystemKey,
  WeblinkObjectService.systemKey,
];
