import 'package:drift/drift.dart' show Variable;

import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'image_object_service.dart';
import 'object_store.dart';
import 'object_type_defaults_store.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';
import 'system_object_store.dart';
import 'weblink_image_schema_service.dart';
import 'weblink_object_service.dart';

class BookmarkWeblinkMediaState {
  BookmarkWeblinkMediaState({
    required Iterable<int> imageObjectIds,
    required this.coverImageObjectId,
  }) : imageObjectIds = List<int>.unmodifiable(imageObjectIds);

  static final empty = BookmarkWeblinkMediaState(
    imageObjectIds: const <int>[],
    coverImageObjectId: null,
  );

  final List<int> imageObjectIds;
  final int? coverImageObjectId;

  bool get isEmpty => imageObjectIds.isEmpty && coverImageObjectId == null;
}

class BookmarkWeblinkMediaSourceSnapshot {
  BookmarkWeblinkMediaSourceSnapshot(
    Map<int, BookmarkWeblinkMediaState> mediaByBookmarkObjectId, {
    required Map<int, int?> weblinkObjectIdByBookmarkObjectId,
    required this.canonicalTargetSchemaExisted,
  }) : _mediaByBookmarkObjectId =
           Map<int, BookmarkWeblinkMediaState>.unmodifiable(
             mediaByBookmarkObjectId,
           ),
       _weblinkObjectIdByBookmarkObjectId = Map<int, int?>.unmodifiable(
         weblinkObjectIdByBookmarkObjectId,
       );

  static final empty = BookmarkWeblinkMediaSourceSnapshot(
    const <int, BookmarkWeblinkMediaState>{},
    weblinkObjectIdByBookmarkObjectId: const <int, int?>{},
    canonicalTargetSchemaExisted: false,
  );

  final Map<int, BookmarkWeblinkMediaState> _mediaByBookmarkObjectId;
  final Map<int, int?> _weblinkObjectIdByBookmarkObjectId;
  final bool canonicalTargetSchemaExisted;

  BookmarkWeblinkMediaState? mediaFor(int bookmarkObjectId) =>
      _mediaByBookmarkObjectId[bookmarkObjectId];

  bool wasLinkedTo(int bookmarkObjectId, int weblinkObjectId) =>
      _weblinkObjectIdByBookmarkObjectId.containsKey(bookmarkObjectId) &&
      _weblinkObjectIdByBookmarkObjectId[bookmarkObjectId] == weblinkObjectId;
}

class BookmarkWeblinkMediaConvergenceReport {
  const BookmarkWeblinkMediaConvergenceReport({
    required this.bookmarkCount,
    required this.weblinkCount,
    required this.convergedWeblinkCount,
    required this.unchangedWeblinkCount,
    this.mutatedWeblinkObjectIds = const <int>[],
  });

  static const empty = BookmarkWeblinkMediaConvergenceReport(
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

/// Converges transition-only Bookmark Image Relations onto canonical Weblinks.
///
/// The compatibility source is the strict tuple `(ordered Images, Cover Image?)`.
/// The canonical target is `(ordered Related images, Representative image?)`.
/// No extra checkpoint/tree/edge store is created: live reconciliation uses only
/// the previous strictly valid mirrored Bookmark source captured before Core
/// compatibility refresh. Legacy-only changes may advance an established target,
/// canonical-only Weblink media is preserved, and independent edits fail closed.
class BookmarkWeblinkMediaConvergenceService {
  BookmarkWeblinkMediaConvergenceService({
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
    _weblinkImages = WeblinkImageSchemaService(
      systemObjects: systemObjectStore,
      defaultsStore: ObjectTypeDefaultsStore(_genericStore),
    );
  }

  static const bookmarkSystemKey = 'bookmark';
  static const bookmarkWeblinkRelationName = 'Weblink';
  static const bookmarkImagesRelationName = 'Images';
  static const bookmarkCoverRelationName = 'Cover Image';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  final GenericDatabaseStore _genericStore;
  late final RelationTargetService _targets;
  late final RelationMutationService _mutations;
  late final WeblinkImageSchemaService _weblinkImages;

  Future<BookmarkWeblinkMediaSourceSnapshot> captureSourceSnapshot(
    int workspaceId,
  ) => database.transaction(() async {
    final bookmarkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
    );
    final imageType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
    );
    if (bookmarkType == null || imageType == null) {
      return BookmarkWeblinkMediaSourceSnapshot.empty;
    }

    final imageProperties = bookmarkType.properties
        .where((property) => property.name == bookmarkImagesRelationName)
        .toList(growable: false);
    final coverProperties = bookmarkType.properties
        .where((property) => property.name == bookmarkCoverRelationName)
        .toList(growable: false);
    if (imageProperties.isEmpty && coverProperties.isEmpty) {
      return BookmarkWeblinkMediaSourceSnapshot.empty;
    }
    final bookmarkImages = _requiredRelation(
      bookmarkType,
      name: bookmarkImagesRelationName,
      targetObjectTypeId: imageType.id,
      multiple: true,
    );
    final bookmarkCover = _requiredRelation(
      bookmarkType,
      name: bookmarkCoverRelationName,
      targetObjectTypeId: imageType.id,
      multiple: false,
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

    var canonicalTargetSchemaExisted = false;
    if (weblinkType != null) {
      final representative = weblinkType.properties
          .where(
            (property) =>
                property.name ==
                WeblinkImageSchemaService.representativeImageName,
          )
          .toList(growable: false);
      final related = weblinkType.properties
          .where(
            (property) =>
                property.name == WeblinkImageSchemaService.relatedImagesName,
          )
          .toList(growable: false);
      if (representative.isNotEmpty || related.isNotEmpty) {
        _requiredRelation(
          weblinkType,
          name: WeblinkImageSchemaService.representativeImageName,
          targetObjectTypeId: imageType.id,
          multiple: false,
        );
        _requiredRelation(
          weblinkType,
          name: WeblinkImageSchemaService.relatedImagesName,
          targetObjectTypeId: imageType.id,
          multiple: true,
        );
        canonicalTargetSchemaExisted = true;
      }
    }

    final objectIds = await _mirroredBookmarkObjectIds(workspaceId);
    final mediaByBookmark = <int, BookmarkWeblinkMediaState>{};
    final weblinkObjectIdByBookmark = <int, int?>{};
    for (final bookmarkObjectId in objectIds) {
      final media = await _loadSourceState(
        workspaceId: workspaceId,
        bookmarkObjectId: bookmarkObjectId,
        imagesProperty: bookmarkImages,
        coverProperty: bookmarkCover,
      );
      mediaByBookmark[bookmarkObjectId] = media;

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

    return BookmarkWeblinkMediaSourceSnapshot(
      mediaByBookmark,
      weblinkObjectIdByBookmarkObjectId: weblinkObjectIdByBookmark,
      canonicalTargetSchemaExisted: canonicalTargetSchemaExisted,
    );
  });

  Future<BookmarkWeblinkMediaConvergenceReport> reconcileWorkspace(
    int workspaceId,
  ) async {
    final objectIds = await _mirroredBookmarkObjectIds(workspaceId);
    return reconcileBookmarkObjects(workspaceId, bookmarkObjectIds: objectIds);
  }

  Future<BookmarkWeblinkMediaConvergenceReport> reconcileAfterWeblinkSync(
    int workspaceId, {
    BookmarkWeblinkMediaSourceSnapshot? previousSource,
  }) async {
    final objectIds = await _mirroredBookmarkObjectIds(workspaceId);
    return _reconcileBookmarkObjects(
      workspaceId,
      bookmarkObjectIds: objectIds,
      previousSource: previousSource,
      skipUnlinkedWeblinks: true,
    );
  }

  Future<BookmarkWeblinkMediaConvergenceReport> reconcileBookmarkObjects(
    int workspaceId, {
    required Iterable<int> bookmarkObjectIds,
    BookmarkWeblinkMediaSourceSnapshot? previousSource,
  }) => _reconcileBookmarkObjects(
    workspaceId,
    bookmarkObjectIds: bookmarkObjectIds,
    previousSource: previousSource,
    skipUnlinkedWeblinks: false,
  );

  Future<BookmarkWeblinkMediaConvergenceReport> _reconcileBookmarkObjects(
    int workspaceId, {
    required Iterable<int> bookmarkObjectIds,
    required bool skipUnlinkedWeblinks,
    BookmarkWeblinkMediaSourceSnapshot? previousSource,
  }) => database.transaction(() async {
    final sourceObjectIds = bookmarkObjectIds.toSet().toList()..sort();
    if (sourceObjectIds.isEmpty) {
      return BookmarkWeblinkMediaConvergenceReport.empty;
    }

    final bookmarkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
    );
    final weblinkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    final imageType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
    );
    if (bookmarkType == null || weblinkType == null || imageType == null) {
      throw StateError(
        'Bookmark media convergence requires canonical Bookmark, Weblink, and Image ObjectTypes.',
      );
    }

    final bookmarkWeblink = _requiredRelation(
      bookmarkType,
      name: bookmarkWeblinkRelationName,
      targetObjectTypeId: weblinkType.id,
      multiple: false,
    );
    final bookmarkImages = _requiredRelation(
      bookmarkType,
      name: bookmarkImagesRelationName,
      targetObjectTypeId: imageType.id,
      multiple: true,
    );
    final bookmarkCover = _requiredRelation(
      bookmarkType,
      name: bookmarkCoverRelationName,
      targetObjectTypeId: imageType.id,
      multiple: false,
    );

    final sourcesByWeblink = <int, _WeblinkMediaSourceState>{};
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
          'Mirrored Bookmark must have exactly one canonical Weblink before media convergence.',
        );
      }

      final currentMedia = await _loadSourceState(
        workspaceId: workspaceId,
        bookmarkObjectId: bookmarkObjectId,
        imagesProperty: bookmarkImages,
        coverProperty: bookmarkCover,
      );
      eligibleBookmarkCount += 1;
      final weblinkObjectId = weblinkContext.selectedObjectIds.single;
      final previousMedia = previousSource?.mediaFor(bookmarkObjectId);
      final canBootstrapTarget =
          previousSource == null ||
          !previousSource.canonicalTargetSchemaExisted ||
          previousMedia == null ||
          !previousSource.wasLinkedTo(bookmarkObjectId, weblinkObjectId);

      final existing = sourcesByWeblink[weblinkObjectId];
      if (existing == null) {
        sourcesByWeblink[weblinkObjectId] = _WeblinkMediaSourceState(
          currentMedia: currentMedia,
          previousMedia: previousMedia,
          previousComplete: previousMedia != null,
          bootstrapTarget: canBootstrapTarget,
        );
        continue;
      }
      if (!_sameState(existing.currentMedia, currentMedia)) {
        throw StateError(
          'Multiple Bookmarks for one Weblink have conflicting Image/Cover Relations.',
        );
      }
      existing.addPrevious(
        previousMedia,
        canBootstrapTarget: canBootstrapTarget,
        sameState: _sameState,
      );
    }

    if (sourcesByWeblink.isEmpty) {
      return BookmarkWeblinkMediaConvergenceReport.empty;
    }

    final targetSchema = await _weblinkImages.ensureDefinition(workspaceId);
    final writes = <int, BookmarkWeblinkMediaState>{};
    var unchangedCount = 0;
    for (final entry in sourcesByWeblink.entries) {
      final currentTarget = await _loadTargetState(
        workspaceId: workspaceId,
        weblinkObjectId: entry.key,
        relatedProperty: targetSchema.relatedImagesProperty,
        representativeProperty: targetSchema.representativeImageProperty,
      );
      final source = entry.value;
      if (_sameState(currentTarget, source.currentMedia)) {
        unchangedCount += 1;
        continue;
      }

      final previousMedia = source.previousComplete
          ? source.previousMedia
          : null;
      if (previousMedia == null) {
        if (!currentTarget.isEmpty) {
          throw StateError(
            'Canonical Weblink already has conflicting Related/Representative Image Relations.',
          );
        }
        if (!source.bootstrapTarget && previousSource != null) {
          throw StateError(
            'Bookmark media reconciliation history is incomplete for an established canonical Weblink target.',
          );
        }
        writes[entry.key] = source.currentMedia;
        continue;
      }

      if (source.bootstrapTarget && currentTarget.isEmpty) {
        writes[entry.key] = source.currentMedia;
        continue;
      }

      final sourceChanged = !_sameState(source.currentMedia, previousMedia);
      final targetStillPrevious = _sameState(currentTarget, previousMedia);
      if (sourceChanged && targetStillPrevious) {
        writes[entry.key] = source.currentMedia;
        continue;
      }
      if (!sourceChanged && !targetStillPrevious) {
        if (source.bootstrapTarget) {
          throw StateError(
            'Canonical Weblink already has conflicting Related/Representative Image Relations.',
          );
        }
        unchangedCount += 1;
        continue;
      }
      throw StateError(
        'Legacy Bookmark media and canonical Weblink media changed independently; refusing to choose an authority.',
      );
    }

    for (final entry in writes.entries) {
      await _mutations.setRelation(
        objectId: entry.key,
        property: targetSchema.relatedImagesProperty,
        targetObjectIds: entry.value.imageObjectIds,
      );
      await _mutations.setRelation(
        objectId: entry.key,
        property: targetSchema.representativeImageProperty,
        targetObjectIds: entry.value.coverImageObjectId == null
            ? const <int>[]
            : <int>[entry.value.coverImageObjectId!],
      );
    }

    for (final entry in writes.entries) {
      final verified = await _loadTargetState(
        workspaceId: workspaceId,
        weblinkObjectId: entry.key,
        relatedProperty: targetSchema.relatedImagesProperty,
        representativeProperty: targetSchema.representativeImageProperty,
      );
      if (!_sameState(verified, entry.value)) {
        throw StateError(
          'Canonical Weblink media Relation verification failed after convergence.',
        );
      }
    }

    final mutatedWeblinkObjectIds = writes.keys.toList()..sort();
    return BookmarkWeblinkMediaConvergenceReport(
      bookmarkCount: eligibleBookmarkCount,
      weblinkCount: sourcesByWeblink.length,
      convergedWeblinkCount: writes.length,
      unchangedWeblinkCount: unchangedCount,
      mutatedWeblinkObjectIds: List<int>.unmodifiable(mutatedWeblinkObjectIds),
    );
  });

  Future<BookmarkWeblinkMediaState> _loadSourceState({
    required int workspaceId,
    required int bookmarkObjectId,
    required ObjectPropertyDefinition imagesProperty,
    required ObjectPropertyDefinition coverProperty,
  }) async {
    final images = await _targets.selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: bookmarkObjectId,
      property: imagesProperty,
    );
    final cover = await _targets.selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: bookmarkObjectId,
      property: coverProperty,
    );
    final coverImageObjectId = cover.selectedObjectIds.isEmpty
        ? null
        : cover.selectedObjectIds.single;
    if (coverImageObjectId != null &&
        !images.selectedObjectIds.contains(coverImageObjectId)) {
      throw StateError(
        'Mirrored Bookmark Cover Image must also be present in its Images Relation.',
      );
    }
    return BookmarkWeblinkMediaState(
      imageObjectIds: images.selectedObjectIds,
      coverImageObjectId: coverImageObjectId,
    );
  }

  Future<BookmarkWeblinkMediaState> _loadTargetState({
    required int workspaceId,
    required int weblinkObjectId,
    required ObjectPropertyDefinition relatedProperty,
    required ObjectPropertyDefinition representativeProperty,
  }) async {
    final related = await _targets.selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: weblinkObjectId,
      property: relatedProperty,
    );
    final representative = await _targets.selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: weblinkObjectId,
      property: representativeProperty,
    );
    return BookmarkWeblinkMediaState(
      imageObjectIds: related.selectedObjectIds,
      coverImageObjectId: representative.selectedObjectIds.isEmpty
          ? null
          : representative.selectedObjectIds.single,
    );
  }

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

  bool _sameState(
    BookmarkWeblinkMediaState left,
    BookmarkWeblinkMediaState right,
  ) {
    if (left.coverImageObjectId != right.coverImageObjectId ||
        left.imageObjectIds.length != right.imageObjectIds.length) {
      return false;
    }
    for (var index = 0; index < left.imageObjectIds.length; index += 1) {
      if (left.imageObjectIds[index] != right.imageObjectIds[index]) {
        return false;
      }
    }
    return true;
  }
}

class _WeblinkMediaSourceState {
  _WeblinkMediaSourceState({
    required this.currentMedia,
    required this.previousMedia,
    required this.previousComplete,
    required this.bootstrapTarget,
  });

  final BookmarkWeblinkMediaState currentMedia;
  BookmarkWeblinkMediaState? previousMedia;
  bool previousComplete;
  bool bootstrapTarget;

  void addPrevious(
    BookmarkWeblinkMediaState? candidate, {
    required bool canBootstrapTarget,
    required bool Function(BookmarkWeblinkMediaState, BookmarkWeblinkMediaState)
    sameState,
  }) {
    bootstrapTarget = bootstrapTarget && canBootstrapTarget;
    if (!previousComplete) return;
    final previous = previousMedia;
    if (candidate == null ||
        previous == null ||
        !sameState(previous, candidate)) {
      previousComplete = false;
      previousMedia = null;
    }
  }
}
