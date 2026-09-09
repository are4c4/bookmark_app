import 'package:drift/drift.dart' show Variable;

import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';
import 'system_object_store.dart';
import 'tag_object_bridge.dart';
import 'weblink_object_service.dart';

class BookmarkWeblinkTagSourceSnapshot {
  BookmarkWeblinkTagSourceSnapshot(
    Map<int, List<int>> tagIdsByBookmarkObjectId, {
    required Map<int, int?> weblinkObjectIdByBookmarkObjectId,
    required this.canonicalTargetPropertyExisted,
  }) : _tagIdsByBookmarkObjectId = Map<int, List<int>>.unmodifiable(
         tagIdsByBookmarkObjectId.map(
           (objectId, tagIds) =>
               MapEntry(objectId, List<int>.unmodifiable(tagIds)),
         ),
       ),
       _weblinkObjectIdByBookmarkObjectId = Map<int, int?>.unmodifiable(
         weblinkObjectIdByBookmarkObjectId,
       );

  static final empty = BookmarkWeblinkTagSourceSnapshot(
    const <int, List<int>>{},
    weblinkObjectIdByBookmarkObjectId: const <int, int?>{},
    canonicalTargetPropertyExisted: false,
  );

  final Map<int, List<int>> _tagIdsByBookmarkObjectId;
  final Map<int, int?> _weblinkObjectIdByBookmarkObjectId;
  final bool canonicalTargetPropertyExisted;

  List<int>? tagIdsFor(int bookmarkObjectId) =>
      _tagIdsByBookmarkObjectId[bookmarkObjectId];

  bool wasLinkedTo(int bookmarkObjectId, int weblinkObjectId) =>
      _weblinkObjectIdByBookmarkObjectId.containsKey(bookmarkObjectId) &&
      _weblinkObjectIdByBookmarkObjectId[bookmarkObjectId] == weblinkObjectId;
}

class BookmarkWeblinkTagConvergenceReport {
  const BookmarkWeblinkTagConvergenceReport({
    required this.bookmarkCount,
    required this.weblinkCount,
    required this.convergedWeblinkCount,
    required this.unchangedWeblinkCount,
    this.mutatedWeblinkObjectIds = const <int>[],
  });

  static const empty = BookmarkWeblinkTagConvergenceReport(
    bookmarkCount: 0,
    weblinkCount: 0,
    convergedWeblinkCount: 0,
    unchangedWeblinkCount: 0,
  );

  final int bookmarkCount;
  final int weblinkCount;
  final int convergedWeblinkCount;
  final int unchangedWeblinkCount;
  final List<int> mutatedWeblinkObjectIds;
}

/// Converges transition-only Bookmark direct Tag Relations onto canonical
/// Weblinks without inventing a second Tag or edge authority.
///
/// All source and target Relation state is strictly validated before any write.
/// Multiple legacy Bookmarks may share one canonical Weblink only when their
/// ordered direct Tag Relations are identical. During live compatibility sync,
/// the previous mirrored Bookmark Tags act only as a reconciliation checkpoint:
/// a legacy-only change can advance Weblink Tags, a canonical-only change is
/// preserved, and independent changes on both sides fail closed.
class BookmarkWeblinkTagConvergenceService {
  BookmarkWeblinkTagConvergenceService({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
  }) : _genericStore = GenericDatabaseStore(database) {
    _targets = RelationTargetService(objectStore);
    _mutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: _genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: _genericStore,
        objectStore: objectStore,
      ),
    );
  }

  static const bookmarkSystemKey = 'bookmark';
  static const bookmarkWeblinkRelationName = 'Weblink';
  static const tagsRelationName = 'Tags';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  final GenericDatabaseStore _genericStore;
  late final RelationTargetService _targets;
  late final RelationMutationService _mutations;

  /// Captures the last strictly valid mirrored Bookmark direct-Tag state before
  /// CoreObjectBridge refreshes that compatibility projection from legacy rows.
  ///
  /// The snapshot also records whether the canonical Weblink Tags schema already
  /// existed and each Bookmark's previous Weblink target. Those facts separate
  /// a first-upgrade/new-target bootstrap from an established canonical target
  /// whose empty or different Tags may be an intentional canonical-only edit.
  Future<BookmarkWeblinkTagSourceSnapshot> captureSourceSnapshot(
    int workspaceId,
  ) => database.transaction(() async {
    final bookmarkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
    );
    final tagType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
    );
    if (bookmarkType == null || tagType == null) {
      return BookmarkWeblinkTagSourceSnapshot.empty;
    }

    final tagProperties = bookmarkType.properties
        .where((property) => property.name == tagsRelationName)
        .toList(growable: false);
    if (tagProperties.isEmpty) {
      return BookmarkWeblinkTagSourceSnapshot.empty;
    }
    final bookmarkTags = _requiredRelation(
      bookmarkType,
      name: tagsRelationName,
      targetObjectTypeId: tagType.id,
      multiple: true,
    );

    final weblinkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    ObjectPropertyDefinition? bookmarkWeblink;
    final bookmarkWeblinkProperties = bookmarkType.properties
        .where((property) => property.name == bookmarkWeblinkRelationName)
        .toList(growable: false);
    if (bookmarkWeblinkProperties.isNotEmpty) {
      if (weblinkType == null) {
        throw StateError(
          'Mirrored Bookmark Weblink Relation exists without the canonical Weblink ObjectType.',
        );
      }
      bookmarkWeblink = _requiredRelation(
        bookmarkType,
        name: bookmarkWeblinkRelationName,
        targetObjectTypeId: weblinkType.id,
        multiple: false,
      );
    }

    var canonicalTargetPropertyExisted = false;
    if (weblinkType != null) {
      final targetTagProperties = weblinkType.properties
          .where((property) => property.name == tagsRelationName)
          .toList(growable: false);
      if (targetTagProperties.isNotEmpty) {
        _requiredRelation(
          weblinkType,
          name: tagsRelationName,
          targetObjectTypeId: tagType.id,
          multiple: true,
        );
        canonicalTargetPropertyExisted = true;
      }
    }

    final objectIds = await _mirroredBookmarkObjectIds(workspaceId);
    final tagIdsByBookmark = <int, List<int>>{};
    final weblinkObjectIdByBookmark = <int, int?>{};
    for (final bookmarkObjectId in objectIds) {
      final context = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: bookmarkObjectId,
        property: bookmarkTags,
      );
      tagIdsByBookmark[bookmarkObjectId] = List<int>.unmodifiable(
        context.selectedObjectIds,
      );

      if (bookmarkWeblink != null) {
        final weblinkContext = await _targets.selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: bookmarkObjectId,
          property: bookmarkWeblink,
        );
        weblinkObjectIdByBookmark[bookmarkObjectId] =
            weblinkContext.selectedObjectIds.isEmpty
            ? null
            : weblinkContext.selectedObjectIds.single;
      }
    }
    return BookmarkWeblinkTagSourceSnapshot(
      tagIdsByBookmark,
      weblinkObjectIdByBookmarkObjectId: weblinkObjectIdByBookmark,
      canonicalTargetPropertyExisted: canonicalTargetPropertyExisted,
    );
  });

  Future<BookmarkWeblinkTagConvergenceReport> reconcileWorkspace(
    int workspaceId,
  ) async {
    final objectIds = await _mirroredBookmarkObjectIds(workspaceId);
    return reconcileBookmarkObjects(workspaceId, bookmarkObjectIds: objectIds);
  }

  /// Runs after BookmarkWeblinkObjectBridge has refreshed canonical Weblink
  /// Relations. A zero-target Bookmark is the bridge's preserved invalid-URL
  /// compatibility state and is skipped here; every linked source remains
  /// strictly validated below. This keeps eligibility inside B without adding a
  /// report-field dependency to the A-owned bridge.
  Future<BookmarkWeblinkTagConvergenceReport> reconcileAfterWeblinkSync(
    int workspaceId, {
    BookmarkWeblinkTagSourceSnapshot? previousSource,
  }) async {
    final objectIds = await _mirroredBookmarkObjectIds(workspaceId);
    return _reconcileBookmarkObjects(
      workspaceId,
      bookmarkObjectIds: objectIds,
      previousSource: previousSource,
      skipUnlinkedWeblinks: true,
    );
  }

  /// Strict explicit convergence. Every supplied Bookmark must have exactly one
  /// canonical Weblink; missing Weblink state fails closed.
  Future<BookmarkWeblinkTagConvergenceReport> reconcileBookmarkObjects(
    int workspaceId, {
    required Iterable<int> bookmarkObjectIds,
    BookmarkWeblinkTagSourceSnapshot? previousSource,
  }) => _reconcileBookmarkObjects(
    workspaceId,
    bookmarkObjectIds: bookmarkObjectIds,
    previousSource: previousSource,
    skipUnlinkedWeblinks: false,
  );

  Future<BookmarkWeblinkTagConvergenceReport> _reconcileBookmarkObjects(
    int workspaceId, {
    required Iterable<int> bookmarkObjectIds,
    required bool skipUnlinkedWeblinks,
    BookmarkWeblinkTagSourceSnapshot? previousSource,
  }) => database.transaction(() async {
    final sourceObjectIds = bookmarkObjectIds.toSet().toList()..sort();
    if (sourceObjectIds.isEmpty) {
      return BookmarkWeblinkTagConvergenceReport.empty;
    }

    final bookmarkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
    );
    final weblinkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    final tagType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
    );
    if (bookmarkType == null || weblinkType == null || tagType == null) {
      throw StateError(
        'Bookmark Tag convergence requires canonical Bookmark, Weblink, and Tag ObjectTypes.',
      );
    }

    final bookmarkWeblink = _requiredRelation(
      bookmarkType,
      name: bookmarkWeblinkRelationName,
      targetObjectTypeId: weblinkType.id,
      multiple: false,
    );
    final bookmarkTags = _requiredRelation(
      bookmarkType,
      name: tagsRelationName,
      targetObjectTypeId: tagType.id,
      multiple: true,
    );

    final sourcesByWeblink = <int, _WeblinkSourceState>{};
    var eligibleBookmarkCount = 0;
    for (final bookmarkObjectId in sourceObjectIds) {
      final weblinkContext = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: bookmarkObjectId,
        property: bookmarkWeblink,
      );
      if (weblinkContext.selectedObjectIds.isEmpty && skipUnlinkedWeblinks) {
        continue;
      }
      if (weblinkContext.selectedObjectIds.length != 1) {
        throw StateError(
          'Mirrored Bookmark must have exactly one canonical Weblink before Tag convergence.',
        );
      }

      final tagContext = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: bookmarkObjectId,
        property: bookmarkTags,
      );
      eligibleBookmarkCount += 1;
      final weblinkObjectId = weblinkContext.selectedObjectIds.single;
      final currentTagIds = List<int>.unmodifiable(
        tagContext.selectedObjectIds,
      );
      final previousTagIds = previousSource?.tagIdsFor(bookmarkObjectId);
      final canBootstrapTarget =
          previousSource == null ||
          !previousSource.canonicalTargetPropertyExisted ||
          previousTagIds == null ||
          !previousSource.wasLinkedTo(bookmarkObjectId, weblinkObjectId);
      final existing = sourcesByWeblink[weblinkObjectId];
      if (existing == null) {
        sourcesByWeblink[weblinkObjectId] = _WeblinkSourceState(
          currentTagIds: currentTagIds,
          previousTagIds: previousTagIds,
          previousComplete: previousTagIds != null,
          bootstrapTarget: canBootstrapTarget,
        );
        continue;
      }
      if (!_sameIds(existing.currentTagIds, currentTagIds)) {
        throw StateError(
          'Multiple Bookmarks for one Weblink have conflicting direct Tag Relations.',
        );
      }
      existing.addPrevious(
        previousTagIds,
        canBootstrapTarget: canBootstrapTarget,
        sameIds: _sameIds,
      );
    }

    if (sourcesByWeblink.isEmpty) {
      return BookmarkWeblinkTagConvergenceReport.empty;
    }

    final weblinkTags = await systemObjectStore.ensureRelationProperty(
      objectTypeId: weblinkType.id,
      name: tagsRelationName,
      targetObjectTypeId: tagType.id,
      multiple: true,
    );
    final writes = <int, List<int>>{};
    var unchangedCount = 0;
    for (final entry in sourcesByWeblink.entries) {
      final targetContext = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: entry.key,
        property: weblinkTags,
      );
      final currentTarget = targetContext.selectedObjectIds;
      final source = entry.value;
      if (_sameIds(currentTarget, source.currentTagIds)) {
        unchangedCount += 1;
        continue;
      }

      final previousTagIds = source.previousComplete
          ? source.previousTagIds
          : null;
      if (previousTagIds == null) {
        if (currentTarget.isNotEmpty) {
          throw StateError(
            'Canonical Weblink already has conflicting direct Tag Relations.',
          );
        }
        if (!source.bootstrapTarget && previousSource != null) {
          throw StateError(
            'Bookmark Tag reconciliation history is incomplete for an established canonical Weblink target.',
          );
        }
        writes[entry.key] = source.currentTagIds;
        continue;
      }

      if (source.bootstrapTarget && currentTarget.isEmpty) {
        writes[entry.key] = source.currentTagIds;
        continue;
      }

      final sourceChanged = !_sameIds(source.currentTagIds, previousTagIds);
      final targetStillPrevious = _sameIds(currentTarget, previousTagIds);
      if (sourceChanged && targetStillPrevious) {
        writes[entry.key] = source.currentTagIds;
        continue;
      }
      if (!sourceChanged && !targetStillPrevious) {
        if (source.bootstrapTarget) {
          throw StateError(
            'Canonical Weblink already has conflicting direct Tag Relations.',
          );
        }
        // Canonical-only edits are first-class Object state. Preserve them while
        // the same legacy compatibility source remains unchanged and attached
        // to the same canonical Weblink target.
        unchangedCount += 1;
        continue;
      }
      throw StateError(
        'Legacy Bookmark Tags and canonical Weblink Tags changed independently; refusing to choose an authority.',
      );
    }

    for (final entry in writes.entries) {
      await _mutations.setRelation(
        objectId: entry.key,
        property: weblinkTags,
        targetObjectIds: entry.value,
      );
    }

    for (final entry in writes.entries) {
      final verified = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: entry.key,
        property: weblinkTags,
      );
      if (!_sameIds(verified.selectedObjectIds, entry.value)) {
        throw StateError(
          'Canonical Weblink Tag Relation verification failed after convergence.',
        );
      }
    }

    final mutatedWeblinkObjectIds = writes.keys.toList()..sort();
    return BookmarkWeblinkTagConvergenceReport(
      bookmarkCount: eligibleBookmarkCount,
      weblinkCount: sourcesByWeblink.length,
      convergedWeblinkCount: writes.length,
      unchangedWeblinkCount: unchangedCount,
      mutatedWeblinkObjectIds: List<int>.unmodifiable(mutatedWeblinkObjectIds),
    );
  });

  Future<List<int>> _mirroredBookmarkObjectIds(int workspaceId) async {
    final rows = await database
        .customSelect(
          '''SELECT object_id
             FROM bookmark_object_links
             WHERE workspace_id = ?
             ORDER BY bookmark_id''',
          variables: [Variable<int>(workspaceId)],
        )
        .get();
    return rows
        .map((row) => row.read<int>('object_id'))
        .toList(growable: false);
  }

  ObjectPropertyDefinition _requiredRelation(
    AppObjectType sourceType, {
    required String name,
    required int targetObjectTypeId,
    required bool multiple,
  }) {
    final matches = sourceType.properties
        .where((property) => property.name == name)
        .toList(growable: false);
    if (matches.length != 1) {
      throw StateError(
        'Canonical ${sourceType.name} ObjectType must contain exactly one "$name" Relation.',
      );
    }
    final property = matches.single;
    if (!property.isRelation ||
        property.targetObjectTypeId != targetObjectTypeId ||
        property.allowsMultipleRelations != multiple) {
      throw StateError(
        'Canonical ${sourceType.name} "$name" does not match the required Relation schema.',
      );
    }
    return property;
  }

  bool _sameIds(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class _WeblinkSourceState {
  _WeblinkSourceState({
    required this.currentTagIds,
    required this.previousTagIds,
    required this.previousComplete,
    required this.bootstrapTarget,
  });

  final List<int> currentTagIds;
  List<int>? previousTagIds;
  bool previousComplete;
  bool bootstrapTarget;

  void addPrevious(
    List<int>? candidate, {
    required bool canBootstrapTarget,
    required bool Function(List<int>, List<int>) sameIds,
  }) {
    bootstrapTarget = bootstrapTarget && canBootstrapTarget;
    if (!previousComplete) return;
    final previous = previousTagIds;
    if (candidate == null ||
        previous == null ||
        !sameIds(previous, candidate)) {
      previousComplete = false;
      previousTagIds = null;
    }
  }
}
