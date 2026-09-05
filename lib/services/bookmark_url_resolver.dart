import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/bookmark_weblink_object_bridge.dart';
import '../data/core_object_bridge.dart';
import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../data/relation_read_service.dart';
import '../data/system_object_store.dart';
import '../data/weblink_object_service.dart';
import '../domain/object_model.dart';

typedef BookmarkUrlResolve = Future<BookmarkUrlSource?> Function(
  BookmarkItem bookmark,
);

enum BookmarkUrlSourceKind {
  canonicalWeblink,
  legacyBookmark,
}

class BookmarkUrlSource {
  const BookmarkUrlSource({
    required this.kind,
    required this.value,
  });

  final BookmarkUrlSourceKind kind;
  final String value;
}

/// Resolves the preferred URL for legacy Bookmark presentation.
///
/// Canonical Bookmark -> Weblink Relation data wins whenever it is healthy.
/// The legacy Bookmark URL remains a compatibility fallback while old hosts are
/// migrated. This resolver is read-only: missing/ambiguous Relation state is
/// never repaired from a presentation path.
class BookmarkUrlResolver {
  BookmarkUrlResolver({
    required this.database,
    required this.workspaceId,
  }) {
    _objectStore = ObjectStore(GenericDatabaseStore(database));
    _systemObjects = SystemObjectStore(
      database: database,
      objectStore: _objectStore,
    );
    _relationReads = RelationReadService(_objectStore);
  }

  final AppDatabase database;
  final int workspaceId;

  late final ObjectStore _objectStore;
  late final SystemObjectStore _systemObjects;
  late final RelationReadService _relationReads;

  BookmarkUrlSource? choosePreferred({
    String? canonicalWeblinkUrl,
    String? legacyBookmarkUrl,
  }) {
    final canonical = _validHttpUrl(canonicalWeblinkUrl);
    if (canonical != null) {
      return BookmarkUrlSource(
        kind: BookmarkUrlSourceKind.canonicalWeblink,
        value: canonical,
      );
    }

    final legacy = _validHttpUrl(legacyBookmarkUrl);
    if (legacy != null) {
      return BookmarkUrlSource(
        kind: BookmarkUrlSourceKind.legacyBookmark,
        value: legacy,
      );
    }
    return null;
  }

  Future<BookmarkUrlSource?> resolve(BookmarkItem bookmark) async {
    final canonical = await resolveCanonicalWeblinkUrl(bookmark.id);
    return choosePreferred(
      canonicalWeblinkUrl: canonical,
      legacyBookmarkUrl: bookmark.url,
    );
  }

  /// Resolves exactly one canonical Bookmark -> Weblink edge and reads the
  /// Weblink URL Property. Ambiguous, missing, malformed, or cross-type state
  /// fails closed so callers can fall back to legacy compatibility data.
  Future<String?> resolveCanonicalWeblinkUrl(int legacyBookmarkId) async {
    if (legacyBookmarkId <= 0 || workspaceId <= 0) return null;

    final bookmarkObjectId = await _bookmarkObjectId(legacyBookmarkId);
    if (bookmarkObjectId == null) return null;

    final bookmarkType = await _systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    );
    final weblinkType = await _systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    if (bookmarkType == null || weblinkType == null) return null;

    final outgoing = await _relationReads.outgoing(
      sourceObjectTypeId: bookmarkType.id,
      sourceObjectId: bookmarkObjectId,
    );
    final edges = outgoing
        .where(
          (entry) =>
              entry.property.name == BookmarkWeblinkObjectBridge.relationName &&
              entry.property.targetObjectTypeId == weblinkType.id &&
              entry.targetObject.objectTypeId == weblinkType.id,
        )
        .toList(growable: false);
    if (edges.length != 1) return null;

    final urlProperties = weblinkType.properties
        .where(
          (property) =>
              property.name == BookmarkWeblinkObjectBridge.legacyUrlPropertyName &&
              property.type == ObjectPropertyType.url,
        )
        .toList(growable: false);
    if (urlProperties.length != 1) return null;

    final raw = edges.single.targetObject.values[urlProperties.single.id];
    return _validHttpUrl(raw == null ? null : '$raw');
  }

  Future<int?> _bookmarkObjectId(int legacyBookmarkId) async {
    try {
      final rows = await database.customSelect(
        '''SELECT object_id
           FROM bookmark_object_links
           WHERE workspace_id = ? AND bookmark_id = ?
           LIMIT 1''',
        variables: [
          Variable<int>(workspaceId),
          Variable<int>(legacyBookmarkId),
        ],
      ).get();
      if (rows.isEmpty) return null;
      return rows.first.read<int>('object_id');
    } catch (_) {
      // Compatibility installations may not have completed Object mirroring.
      return null;
    }
  }

  String? _validHttpUrl(String? value) {
    final candidate = value?.trim();
    if (candidate == null || candidate.isEmpty) return null;
    final uri = Uri.tryParse(candidate);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (scheme != 'http' && scheme != 'https')) {
      return null;
    }
    return candidate;
  }
}
