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

/// Adds the canonical reusable Weblink relation to mirrored Bookmark Objects.
///
/// This bridge is intentionally additive during the migration phase: the
/// legacy Bookmark URL Value remains untouched until relation-first migration
/// has been proven safe. Relation writes always go through
/// [RelationMutationService].
class BookmarkWeblinkObjectBridge {
  BookmarkWeblinkObjectBridge({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
  }) : _genericStore = GenericDatabaseStore(database);

  static const String bookmarkSystemKey = 'bookmark';
  static const String relationName = 'Weblink';

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

  Future<void> syncWorkspace(int workspaceId) async {
    final bookmarkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
    );
    if (bookmarkType == null) return;

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

    for (final row in rows) {
      final objectId = row.read<int>('object_id');
      final rawUrl = row.read<String>('url');
      final targetIds = <int>[];
      try {
        final weblink = await _weblinks.findOrCreate(
          workspaceId: workspaceId,
          url: rawUrl,
        );
        targetIds.add(weblink.id);
      } on ArgumentError {
        // Keep invalid legacy URL data intact and leave the canonical Relation
        // empty. A later user-facing migration can surface/repair the URL.
      }
      await _relationMutations.setRelation(
        objectId: objectId,
        property: relation,
        targetObjectIds: targetIds,
      );
    }
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
