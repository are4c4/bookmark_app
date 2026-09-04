import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
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
      '''SELECT links.object_id AS object_id, bookmarks.url AS url
         FROM bookmark_object_links AS links
         JOIN bookmarks ON bookmarks.id = links.bookmark_id
         WHERE links.workspace_id = ?
         ORDER BY links.bookmark_id''',
      variables: [Variable<int>(workspaceId)],
    ).get();

    var linkedCount = 0;
    var invalidUrlCount = 0;
    var retiredLegacyUrlCount = 0;
    for (final row in rows) {
      final objectId = row.read<int>('object_id');
      final rawUrl = row.read<String>('url');
      int? targetId;
      try {
        final weblink = await _weblinks.findOrCreate(
          workspaceId: workspaceId,
          url: rawUrl,
        );
        targetId = weblink.id;
      } on ArgumentError {
        invalidUrlCount += 1;
      }

      final targetIds = targetId == null ? const <int>[] : <int>[targetId];
      await _relationMutations.setRelation(
        objectId: objectId,
        property: relation,
        targetObjectIds: targetIds,
      );

      if (targetId == null) continue;
      linkedCount += 1;
      final verified = await _isCanonicalRelationPersisted(
        bookmarkObjectTypeId: bookmarkType.id,
        bookmarkObjectId: objectId,
        relationPropertyId: relation.id,
        targetObjectId: targetId,
      );
      if (!verified) {
        throw StateError(
          'Bookmark.Weblink verification failed after canonical Relation write.',
        );
      }

      await objectStore.setPropertyValue(
        objectId: objectId,
        property: legacyUrlProperty,
        value: null,
      );
      retiredLegacyUrlCount += 1;
    }

    return BookmarkWeblinkSyncReport(
      processedCount: rows.length,
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
