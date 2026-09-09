import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'canonical_weblink_capture_service.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'object_type_defaults_store.dart';
import 'relation_mutation_service.dart';
import 'system_object_store.dart';
import 'weblink_object_service.dart';

class BookmarkWeblinkSyncReport {
  const BookmarkWeblinkSyncReport({
    required this.processedCount,
    required this.linkedCount,
    required this.invalidUrlCount,
    required this.retiredLegacyUrlCount,
  });

  static const empty = BookmarkWeblinkSyncReport(
    processedCount: 0,
    linkedCount: 0,
    invalidUrlCount: 0,
    retiredLegacyUrlCount: 0,
  );

  final int processedCount;
  final int linkedCount;
  final int invalidUrlCount;
  final int retiredLegacyUrlCount;
}

class _LegacyBookmarkSavedState {
  const _LegacyBookmarkSavedState({
    required this.favorite,
    required this.readingStatus,
    required this.storageState,
    required this.genre,
    required this.rating,
  });

  final bool favorite;
  final String readingStatus;
  final String storageState;
  final String genre;
  final int rating;

  bool equivalentTo(_LegacyBookmarkSavedState other) =>
      favorite == other.favorite &&
      readingStatus == other.readingStatus &&
      storageState == other.storageState &&
      genre == other.genre &&
      rating == other.rating;
}

class _ResolvedBookmarkWeblinkRow {
  const _ResolvedBookmarkWeblinkRow({
    required this.objectId,
    required this.targetId,
    required this.title,
    required this.description,
    required this.thumbnail,
  });

  final int objectId;
  final int? targetId;
  final String title;
  final String? description;
  final String? thumbnail;
}

/// Adds the canonical reusable Weblink relation to mirrored Bookmark Objects.
///
/// The legacy `bookmarks.url` column remains the compatibility source for the
/// old bookmark UI. The mirrored Bookmark Object's direct URL Value is retired
/// only after the canonical Relation value and normalized index both confirm
/// the expected Weblink target.
class BookmarkWeblinkObjectBridge {
  BookmarkWeblinkObjectBridge({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
  }) : _genericStore = GenericDatabaseStore(database);

  static const String bookmarkSystemKey = 'bookmark';
  static const String relationName = 'Weblink';
  static const String legacyUrlPropertyName = 'URL';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  final GenericDatabaseStore _genericStore;

  late final WeblinkObjectService _weblinks = WeblinkObjectService(
        systemObjects: systemObjectStore,
        defaultsStore: ObjectTypeDefaultsStore(_genericStore),
      );
  late final CanonicalWeblinkCaptureService _capture =
      CanonicalWeblinkCaptureService(weblinks: _weblinks);

  RelationMutationService get _relationMutations => RelationMutationService(
        objectStore: objectStore,
        genericStore: _genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: _genericStore,
          objectStore: objectStore,
        ),
      );

  Future<BookmarkWeblinkSyncReport> syncWorkspace(int workspaceId) async {
    final bookmarkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
    );
    if (bookmarkType == null) return BookmarkWeblinkSyncReport.empty;

    final legacyUrlProperty = bookmarkType.properties.firstWhere(
      (property) => property.name == legacyUrlPropertyName,
    );
    final weblinkDefinition = await _weblinks.ensureDefinition(workspaceId);
    final relation = await systemObjectStore.ensureRelationProperty(
      objectTypeId: bookmarkType.id,
      name: relationName,
      targetObjectTypeId: weblinkDefinition.objectType.id,
      multiple: false,
    );
    _validateRelation(relation, weblinkDefinition.objectType.id);

    final rows = await database.customSelect(
      '''SELECT links.object_id AS object_id,
                bookmarks.url AS url,
                bookmarks.title AS title,
                bookmarks.description AS description,
                bookmarks.thumbnail AS thumbnail,
                bookmarks.favorite AS favorite,
                bookmarks.reading_status AS reading_status,
                bookmarks.storage_state AS storage_state,
                bookmarks.genre AS genre,
                bookmarks.rating AS rating
         FROM bookmark_object_links AS links
         JOIN bookmarks ON bookmarks.id = links.bookmark_id
         WHERE links.workspace_id = ?
         ORDER BY links.bookmark_id''',
      variables: [Variable<int>(workspaceId)],
    ).get();

    // Resolve every canonical identity before mutating any Bookmark Relation or
    // retiring any mirrored URL. Multiple legacy saved-items may legitimately
    // reference one resource, but their saved-item state cannot be collapsed
    // until a lossless destination exists. Resource metadata (title/description/
    // thumbnail) remains compatibility-preserved on the legacy row/mirror and
    // is still only best-effort enrichment below; Relation state is owned by B.
    final resolvedRows = <_ResolvedBookmarkWeblinkRow>[];
    final stateByTargetId = <int, _LegacyBookmarkSavedState>{};
    var invalidUrlCount = 0;
    for (final row in rows) {
      int? targetId;
      try {
        final weblink = await _capture.capture(
          workspaceId: workspaceId,
          url: row.read<String>('url'),
        );
        targetId = weblink.id;
      } on ArgumentError {
        invalidUrlCount += 1;
      }

      if (targetId != null) {
        final state = _LegacyBookmarkSavedState(
          favorite: row.read<int>('favorite') != 0,
          readingStatus: row.read<String>('reading_status'),
          storageState: row.read<String>('storage_state'),
          genre: row.read<String>('genre'),
          rating: row.read<int>('rating'),
        );
        final existing = stateByTargetId[targetId];
        if (existing != null && !existing.equivalentTo(state)) {
          throw StateError(
            'Legacy Bookmark user-state collision: multiple Bookmarks resolve '
            'to one canonical Weblink with non-equivalent saved-item state.',
          );
        }
        stateByTargetId[targetId] = state;
      }

      resolvedRows.add(
        _ResolvedBookmarkWeblinkRow(
          objectId: row.read<int>('object_id'),
          targetId: targetId,
          title: row.read<String>('title'),
          description: row.readNullable<String>('description'),
          thumbnail: row.readNullable<String>('thumbnail'),
        ),
      );
    }

    var linkedCount = 0;
    var retiredLegacyUrlCount = 0;
    for (final row in resolvedRows) {
      final targetIds = row.targetId == null
          ? const <int>[]
          : <int>[row.targetId!];
      await _relationMutations.setRelation(
        objectId: row.objectId,
        property: relation,
        targetObjectIds: targetIds,
      );

      final targetId = row.targetId;
      if (targetId == null) continue;
      linkedCount += 1;
      final verified = await _isCanonicalRelationPersisted(
        bookmarkObjectTypeId: bookmarkType.id,
        bookmarkObjectId: row.objectId,
        relationPropertyId: relation.id,
        targetObjectId: targetId,
      );
      if (!verified) {
        throw StateError(
          'Bookmark.Weblink verification failed after canonical Relation write.',
        );
      }

      await objectStore.setPropertyValue(
        objectId: row.objectId,
        property: legacyUrlProperty,
        value: null,
      );
      retiredLegacyUrlCount += 1;

      // Metadata is best-effort and must never block the canonical Bookmark ->
      // Weblink path. The first Bookmark encountered for a reusable Weblink can
      // seed missing resource metadata; later Bookmarks cannot overwrite it.
      try {
        await _weblinks.enrichIfMissing(
          workspaceId: workspaceId,
          objectId: targetId,
          pageTitle: row.title,
          description: row.description,
          previewImageUrl: row.thumbnail,
        );
      } catch (_) {
        // Keep the verified Relation and legacy Bookmark data intact when
        // optional resource metadata cannot be migrated.
      }
    }

    return BookmarkWeblinkSyncReport(
      processedCount: resolvedRows.length,
      linkedCount: linkedCount,
      invalidUrlCount: invalidUrlCount,
      retiredLegacyUrlCount: retiredLegacyUrlCount,
    );
  }

  Future<bool> _isCanonicalRelationPersisted({
    required int bookmarkObjectTypeId,
    required int bookmarkObjectId,
    required int relationPropertyId,
    required int targetObjectId,
  }) async {
    AppObject? bookmark;
    for (final object in await objectStore.listObjects(bookmarkObjectTypeId)) {
      if (object.id == bookmarkObjectId) {
        bookmark = object;
        break;
      }
    }
    if (bookmark == null) return false;

    final persisted = ObjectRelationValue.fromJson(
      bookmark.values[relationPropertyId],
    ).objectIds;
    if (persisted.length != 1 || persisted.single != targetObjectId) {
      return false;
    }

    final indexed = (await objectStore.outgoingRelations(bookmarkObjectId))
        .where((edge) => edge.propertyId == relationPropertyId)
        .toList(growable: false);
    return indexed.length == 1 && indexed.single.targetObjectId == targetObjectId;
  }

  void _validateRelation(
    ObjectPropertyDefinition relation,
    int weblinkObjectTypeId,
  ) {
    if (!relation.isRelation ||
        relation.targetObjectTypeId != weblinkObjectTypeId ||
        relation.allowsMultipleRelations) {
      throw StateError(
        'Bookmark.Weblink must be a single Relation targeting Weblink.',
      );
    }
  }
}
