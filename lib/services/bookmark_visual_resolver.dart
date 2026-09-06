import 'dart:io';

import '../data/app_database.dart';
import '../data/bookmark_object_link_read_store.dart';
import '../data/bookmark_weblink_object_bridge.dart';
import '../data/core_object_bridge.dart';
import '../data/generic_database_store.dart';
import '../data/image_object_service.dart';
import '../data/object_store.dart';
import '../data/relation_read_service.dart';
import '../data/system_object_store.dart';
import 'image_visual_resolver.dart';
import 'weblink_visual_resolver.dart';

enum BookmarkVisualSourceKind {
  canonicalCover,
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
/// The canonical Bookmark -> Cover Image Relation represents explicit user
/// cover intent and is preferred first. The legacy Photo cover stays as a safe
/// compatibility fallback while migration is in progress, followed by the
/// canonical Bookmark -> Weblink -> Representative image Relation chain and,
/// finally, the legacy remote thumbnail.
///
/// This is a read-only presentation boundary: missing, ambiguous or malformed
/// Relation state fails closed to the next compatibility source and is never
/// repaired from presentation.
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
    _imageVisuals = ImageVisualResolver(
      _objectStore,
      pathResolver: database.pathResolver,
    );
    _weblinkVisuals = WeblinkVisualResolver(
      _objectStore,
      pathResolver: database.pathResolver,
    );
    _bookmarkLinks = BookmarkObjectLinkReadStore(database);
  }

  static const _coverImageRelationName = 'Cover Image';

  final AppDatabase database;
  final int workspaceId;

  late final ObjectStore _objectStore;
  late final SystemObjectStore _systemObjects;
  late final RelationReadService _relationReads;
  late final ImageVisualResolver _imageVisuals;
  late final WeblinkVisualResolver _weblinkVisuals;
  late final BookmarkObjectLinkReadStore _bookmarkLinks;

  BookmarkVisualSource? choosePreferred({
    String? canonicalCoverPath,
    String? userCoverPath,
    String? managedRepresentativePath,
    String? legacyThumbnailUrl,
  }) {
    final canonicalCover = _nonEmpty(canonicalCoverPath);
    if (canonicalCover != null) {
      return BookmarkVisualSource(
        kind: BookmarkVisualSourceKind.canonicalCover,
        value: canonicalCover,
      );
    }

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
    final canonicalCover = await resolveCanonicalCoverPath(bookmark.id);
    final legacyUserCover = await _existingFile(bookmark.coverPhoto?.path);
    final managed = await resolveManagedRepresentativePath(bookmark.id);
    return choosePreferred(
      canonicalCoverPath: canonicalCover,
      userCoverPath: legacyUserCover,
      managedRepresentativePath: managed,
      legacyThumbnailUrl: bookmark.thumbnail,
    );
  }

  /// Resolves the canonical Bookmark -> Cover Image single Relation.
  ///
  /// The Relation must resolve to exactly one edge, be declared single-valued,
  /// target the canonical system Image ObjectType, and point to an existing
  /// managed file. Any malformed/ambiguous state returns `null` so the caller
  /// can use the legacy explicit-cover fallback without mutating data.
  Future<String?> resolveCanonicalCoverPath(int legacyBookmarkId) async {
    if (legacyBookmarkId <= 0 || workspaceId <= 0) return null;

    final bookmarkObjectId = await _bookmarkLinks.objectIdForBookmark(
      workspaceId: workspaceId,
      bookmarkId: legacyBookmarkId,
    );
    if (bookmarkObjectId == null) return null;

    final bookmarkType = await _systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    );
    final imageType = await _systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
    );
    if (bookmarkType == null || imageType == null) return null;

    final outgoing = await _relationReads.outgoing(
      sourceObjectTypeId: bookmarkType.id,
      sourceObjectId: bookmarkObjectId,
    );
    final coverEdges = outgoing
        .where((entry) => entry.property.name == _coverImageRelationName)
        .toList(growable: false);
    if (coverEdges.length != 1) return null;

    final edge = coverEdges.single;
    if (edge.property.allowsMultipleRelations ||
        edge.property.targetObjectTypeId != imageType.id ||
        edge.targetObject.objectTypeId != imageType.id) {
      return null;
    }

    final visual = await _imageVisuals.resolveManaged(
      imageObjectTypeId: imageType.id,
      imageObjectId: edge.targetObject.id,
    );
    return visual?.filePath;
  }

  /// Reads the canonical Bookmark -> Weblink edge, then delegates Weblink media
  /// resolution to the shared presentation resolver used by Object-first hosts.
  ///
  /// No Relation value is decoded directly and no schema is mutated here. If an
  /// expected edge/type/file is missing, presentation falls back rather than
  /// trying to repair ambiguous state.
  Future<String?> resolveManagedRepresentativePath(int legacyBookmarkId) async {
    if (legacyBookmarkId <= 0 || workspaceId <= 0) return null;

    final bookmarkObjectId = await _bookmarkLinks.objectIdForBookmark(
      workspaceId: workspaceId,
      bookmarkId: legacyBookmarkId,
    );
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

    final visual = await _weblinkVisuals.resolveManagedRepresentative(
      weblinkObjectTypeId: weblinkTypeId,
      weblinkObjectId: weblinkEdge.targetObject.id,
    );
    return visual?.filePath;
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
