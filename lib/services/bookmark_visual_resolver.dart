import 'dart:io';

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/bookmark_weblink_object_bridge.dart';
import '../data/core_object_bridge.dart';
import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../data/relation_read_service.dart';
import '../data/system_object_store.dart';
import '../data/weblink_image_schema_service.dart';

enum BookmarkVisualSourceKind {
  userCover,
  managedRepresentative,
  legacyRemote,
}

class BookmarkVisualSource {
  const BookmarkVisualSource({required this.kind, required this.value});

  final BookmarkVisualSourceKind kind;
  final String value;

  bool get isLocalFile => kind != BookmarkVisualSourceKind.legacyRemote;
}

/// Resolves the best visual source for a legacy Bookmark presentation.
///
/// Priority intentionally preserves explicit user choice first, then follows
/// the canonical Bookmark -> Weblink -> Representative image Relation chain,
/// and finally falls back to the legacy remote thumbnail while old hosts still
/// depend on it.
class BookmarkVisualResolver {
  BookmarkVisualResolver({
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

  BookmarkVisualSource? choosePreferred({
    String? userCoverPath,
    String? managedRepresentativePath,
    String? legacyThumbnailUrl,
  }) {
    final userCover = _nonEmpty(userCoverPath);
    if (userCover != null) {
      return BookmarkVisualSource(
        kind: BookmarkVisualSourceKind.userCover,
        value: userCover,
      );
    }

    final managed = _nonEmpty(managedRepresentativePath);
    if (managed != null) {
      return BookmarkVisualSource(
        kind: BookmarkVisualSourceKind.managedRepresentative,
        value: managed,
      );
    }

    final remote = _validRemoteUrl(legacyThumbnailUrl);
    if (remote != null) {
      return BookmarkVisualSource(
        kind: BookmarkVisualSourceKind.legacyRemote,
        value: remote,
      );
    }
    return null;
  }

  Future<BookmarkVisualSource?> resolve(BookmarkItem bookmark) async {
    final userCover = await _existingFile(bookmark.coverPhoto?.path);
    final managed = await resolveManagedRepresentativePath(bookmark.id);
    return choosePreferred(
      userCoverPath: userCover,
      managedRepresentativePath: managed,
      legacyThumbnailUrl: bookmark.thumbnail,
    );
  }

  /// Reads the canonical Relation graph and returns the managed Image File path.
  ///
  /// No Relation value is decoded directly and no schema is mutated here. If an
  /// expected edge/type/file is missing, presentation falls back rather than
  /// trying to repair ambiguous state.
  Future<String?> resolveManagedRepresentativePath(int legacyBookmarkId) async {
    if (legacyBookmarkId <= 0 || workspaceId <= 0) return null;

    final bookmarkObjectId = await _bookmarkObjectId(legacyBookmarkId);
    if (bookmarkObjectId == null) return null;

    final bookmarkType = await _systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    );
    if (bookmarkType == null) return null;

    final bookmarkOutgoing = await _relationReads.outgoing(
      sourceObjectTypeId: bookmarkType.id,
      sourceObjectId: bookmarkObjectId,
    );
    final weblinkEdges = bookmarkOutgoing
        .where(
          (entry) =>
              entry.property.name == BookmarkWeblinkObjectBridge.relationName,
        )
        .toList(growable: false);
    if (weblinkEdges.length != 1) return null;

    final weblinkEdge = weblinkEdges.single;
    final weblinkTypeId = weblinkEdge.property.targetObjectTypeId;
    if (weblinkTypeId == null) return null;

    final weblinkOutgoing = await _relationReads.outgoing(
      sourceObjectTypeId: weblinkTypeId,
      sourceObjectId: weblinkEdge.targetObject.id,
    );
    final representativeEdges = weblinkOutgoing
        .where(
          (entry) =>
              entry.property.name ==
              WeblinkImageSchemaService.representativeImageName,
        )
        .toList(growable: false);
    if (representativeEdges.length != 1) return null;

    final imageEdge = representativeEdges.single;
    final imageTypeId = imageEdge.property.targetObjectTypeId;
    if (imageTypeId == null) return null;
    final imageType = await _objectStore.getObjectType(imageTypeId);
    if (imageType == null) return null;

    final fileProperties = imageType.properties
        .where((property) => property.name == 'File')
        .toList(growable: false);
    if (fileProperties.length != 1) return null;
    final path = _nonEmpty(
      imageEdge.targetObject.values[fileProperties.single.id]?.toString(),
    );
    return _existingFile(path);
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
      // Compatibility installations may not have completed Object mirroring yet.
      return null;
    }
  }

  Future<String?> _existingFile(String? value) async {
    final path = _nonEmpty(value);
    if (path == null) return null;
    try {
      return await File(path).exists() ? path : null;
    } catch (_) {
      return null;
    }
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _validRemoteUrl(String? value) {
    final candidate = _nonEmpty(value);
    if (candidate == null) return null;
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return candidate;
  }
}
