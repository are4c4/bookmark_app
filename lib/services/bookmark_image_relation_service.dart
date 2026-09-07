import 'package:drift/drift.dart' show Variable;

import '../data/app_database.dart';
import '../data/bidirectional_relation_store.dart';
import '../data/bookmark_object_link_read_store.dart';
import '../data/core_object_bridge.dart';
import '../data/generic_database_store.dart';
import '../data/image_object_service.dart';
import '../data/object_alias_store.dart';
import '../data/object_identity_search_service.dart';
import '../data/object_relation_editor_service.dart';
import '../data/object_store.dart';
import '../data/relation_mutation_service.dart';
import '../data/relation_target_service.dart';
import '../data/system_object_store.dart';
import '../data/tag_object_bridge.dart';
import '../domain/object_identity_search.dart';
import '../domain/object_model.dart';

/// Canonical Bookmark -> Image editing boundary used while legacy Photo data is
/// still retained for compatibility.
///
/// Canonical `Images` / `Cover Image` Relations are the editing authority. While
/// old Bookmark Photo callers still exist, the subset of selected Image Objects
/// that have `photo_object_links` is mirrored back into `bookmark_photos` as a
/// compatibility projection. Native Image Objects never acquire legacy rows.
class BookmarkImageRelationService {
  BookmarkImageRelationService(this.database);

  final AppDatabase database;

  late final GenericDatabaseStore _genericStore = GenericDatabaseStore(database);
  late final ObjectStore objectStore = ObjectStore(_genericStore);
  late final SystemObjectStore _systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
  late final RelationMutationService _mutations = RelationMutationService(
        objectStore: objectStore,
        genericStore: _genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: _genericStore,
          objectStore: objectStore,
        ),
      );
  late final ObjectRelationEditorService _editor = ObjectRelationEditorService(
        targets: RelationTargetService(objectStore),
        mutations: _mutations,
        identitySearch: ObjectIdentitySearchService(
          objectStore: objectStore,
          aliasStore: ObjectAliasStore(_genericStore),
        ),
      );
  late final BookmarkObjectLinkReadStore _links =
      BookmarkObjectLinkReadStore(database);
  late final CoreObjectBridge _coreBridge = CoreObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: _systemObjects,
        tagBridge: TagObjectBridge(
          database: database,
          objectStore: objectStore,
          systemObjectStore: _systemObjects,
        ),
      );

  /// Returns null only when this legacy Bookmark has not yet been mirrored into
  /// the canonical Object system. A partially present or incompatible canonical
  /// schema fails closed instead of silently falling back to a second authority.
  Future<BookmarkImageRelationState?> load({
    required int workspaceId,
    required int bookmarkId,
  }) async {
    final bookmarkObjectId = await _links.objectIdForBookmark(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
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
    if (bookmarkType == null || imageType == null) {
      throw StateError(
        'Mirrored Bookmark Image Relations require canonical Bookmark and Image ObjectTypes.',
      );
    }

    final imagesProperty = _relationProperty(
      bookmarkType,
      name: 'Images',
      targetObjectTypeId: imageType.id,
      multiple: true,
    );
    final coverProperty = _relationProperty(
      bookmarkType,
      name: 'Cover Image',
      targetObjectTypeId: imageType.id,
      multiple: false,
    );

    final images = await _editor.load(
      workspaceId: workspaceId,
      sourceObjectId: bookmarkObjectId,
      property: imagesProperty,
    );
    final cover = await _editor.load(
      workspaceId: workspaceId,
      sourceObjectId: bookmarkObjectId,
      property: coverProperty,
    );

    return BookmarkImageRelationState(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
      bookmarkObjectId: bookmarkObjectId,
      images: images,
      cover: cover,
    );
  }

  Future<List<ObjectIdentitySearchResult>> searchImages({
    required BookmarkImageRelationState state,
    required String query,
  }) =>
      _editor.searchCandidates(
        context: state.images,
        query: query,
      );

  /// Compatibility entry point for legacy Photo hosts during #245 migration.
  ///
  /// The Photo must already have a stable `photo_object_links` mapping. Missing
  /// mappings or malformed canonical Relation state fail closed rather than
  /// recreating a second Photo-based write authority.
  Future<void> attachLegacyPhoto({
    required int workspaceId,
    required int bookmarkId,
    required int photoId,
    bool asCover = false,
  }) async {
    final state = await load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    );
    if (state == null) {
      throw StateError(
        'Bookmark must be mirrored before a legacy Photo can attach canonically.',
      );
    }
    if (state.hasDiagnostics) {
      throw StateError(
        'Cannot attach a legacy Photo while Bookmark Image Relations are malformed.',
      );
    }

    final imageObjectId = await _imageObjectIdForLegacyPhoto(
      workspaceId: workspaceId,
      photoId: photoId,
    );
    if (imageObjectId == null) {
      throw StateError(
        'Legacy Photo must be mirrored to a canonical Image before attachment.',
      );
    }
    if (!state.images.candidates.any((image) => image.id == imageObjectId)) {
      throw StateError(
        'Legacy Photo mapping does not target a canonical Image in this workspace.',
      );
    }

    if (asCover) {
      await setCover(
        state: state,
        imageObjectId: imageObjectId,
      );
      return;
    }

    await saveImages(
      state: state,
      selectedObjectIds: <int>[
        ...state.images.selectedObjectIds,
        if (!state.images.selectedObjectIds.contains(imageObjectId))
          imageObjectId,
      ],
    );
  }

  /// Mirrors a freshly-created legacy Bookmark/Photo selection and commits the
  /// result through canonical Image Relations without waiting for the debounced
  /// background Object watcher.
  ///
  /// Every requested Photo mapping is validated before Relation mutation. This
  /// keeps creation fail-closed and avoids partially attaching a multi-photo
  /// selection when one legacy Photo cannot be represented canonically.
  Future<void> saveLegacyPhotosAfterCreate({
    required int workspaceId,
    required int bookmarkId,
    required Iterable<int> photoIds,
    int? coverPhotoId,
  }) async {
    final selectedPhotoIds = <int>[];
    final seenPhotoIds = <int>{};
    for (final photoId in photoIds) {
      if (seenPhotoIds.add(photoId)) selectedPhotoIds.add(photoId);
    }
    if (coverPhotoId != null && !seenPhotoIds.contains(coverPhotoId)) {
      throw ArgumentError.value(
        coverPhotoId,
        'coverPhotoId',
        'Cover Photo must also be included in the selected Photos.',
      );
    }
    if (selectedPhotoIds.isEmpty) return;

    // repository.create() writes legacy Bookmark/workspace rows synchronously,
    // while the app-wide Object watcher mirrors them on a debounce. Creation
    // needs deterministic Relation ownership immediately, so run the existing
    // compatibility bridge once rather than sleeping/polling for that watcher.
    await _coreBridge.syncAll(workspaceId);

    final state = await load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    );
    if (state == null) {
      throw StateError(
        'New Bookmark could not be mirrored before Image Relation creation.',
      );
    }
    if (state.hasDiagnostics) {
      throw StateError(
        'Cannot save created Bookmark Images while Relations are malformed.',
      );
    }

    final candidateImageIds =
        state.images.candidates.map((image) => image.id).toSet();
    final imageByPhotoId = <int, int>{};
    for (final photoId in selectedPhotoIds) {
      final imageObjectId = await _imageObjectIdForLegacyPhoto(
        workspaceId: workspaceId,
        photoId: photoId,
      );
      if (imageObjectId == null) {
        throw StateError(
          'Selected legacy Photo has no canonical Image mapping after mirror.',
        );
      }
      if (!candidateImageIds.contains(imageObjectId)) {
        throw StateError(
          'Selected Photo mapping does not target a canonical Image in this workspace.',
        );
      }
      imageByPhotoId[photoId] = imageObjectId;
    }

    final selectedImageObjectIds = state.images.selectedObjectIds.toList();
    for (final photoId in selectedPhotoIds) {
      final imageObjectId = imageByPhotoId[photoId]!;
      if (!selectedImageObjectIds.contains(imageObjectId)) {
        selectedImageObjectIds.add(imageObjectId);
      }
    }
    final coverImageObjectId = coverPhotoId == null
        ? state.validCoverImageObjectId
        : imageByPhotoId[coverPhotoId];

    await database.transaction(() async {
      await _editor.save(
        context: state.images,
        selectedObjectIds: selectedImageObjectIds,
      );
      await _editor.save(
        context: state.cover,
        selectedObjectIds: coverImageObjectId == null
            ? const <int>[]
            : <int>[coverImageObjectId],
      );
      await _replaceLegacyBookmarkPhotoProjection(
        state: state,
        selectedImageObjectIds: selectedImageObjectIds,
        coverImageObjectId: coverImageObjectId,
      );
    });
  }

  /// Saves the explicit multi-image selection. If the current valid cover is
  /// removed, the cover is cleared in the same database transaction so the
  /// canonical model keeps the legacy invariant that a cover is also related.
  Future<void> saveImages({
    required BookmarkImageRelationState state,
    required Iterable<int> selectedObjectIds,
  }) async {
    final selected = <int>[];
    final seen = <int>{};
    for (final objectId in selectedObjectIds) {
      if (seen.add(objectId)) selected.add(objectId);
    }
    final selectedSet = selected.toSet();
    final currentCoverId = state.validCoverImageObjectId;
    final retainedCoverId = currentCoverId != null &&
            selectedSet.contains(currentCoverId)
        ? currentCoverId
        : null;

    await database.transaction(() async {
      if (currentCoverId != null && retainedCoverId == null) {
        await _editor.save(
          context: state.cover,
          selectedObjectIds: const <int>[],
        );
      }
      await _editor.save(
        context: state.images,
        selectedObjectIds: selected,
      );
      await _replaceLegacyBookmarkPhotoProjection(
        state: state,
        selectedImageObjectIds: selected,
        coverImageObjectId: retainedCoverId,
      );
    });
  }

  /// Makes [imageObjectId] the single canonical cover. Matching legacy behavior,
  /// selecting a cover also adds it to `Images` when it is not already related.
  Future<void> setCover({
    required BookmarkImageRelationState state,
    required int imageObjectId,
  }) async {
    final candidateIds = state.images.candidates.map((item) => item.id).toSet();
    if (!candidateIds.contains(imageObjectId)) {
      throw ArgumentError.value(
        imageObjectId,
        'imageObjectId',
        'Cover Image must be a canonical Image candidate in the same workspace.',
      );
    }

    final imageIds = state.images.selectedObjectIds.toList(growable: true);
    final needsImageAttach = !imageIds.contains(imageObjectId);
    if (needsImageAttach && state.images.missingTargetObjectIds.isNotEmpty) {
      throw StateError(
        'Cannot add a cover while the Images Relation contains missing targets. Resolve the Images selection first.',
      );
    }
    if (needsImageAttach) imageIds.add(imageObjectId);

    await database.transaction(() async {
      if (needsImageAttach) {
        await _editor.save(
          context: state.images,
          selectedObjectIds: imageIds,
        );
      }
      await _editor.save(
        context: state.cover,
        selectedObjectIds: <int>[imageObjectId],
      );
      if (needsImageAttach || state.images.missingTargetObjectIds.isEmpty) {
        await _replaceLegacyBookmarkPhotoProjection(
          state: state,
          selectedImageObjectIds: imageIds,
          coverImageObjectId: imageObjectId,
        );
      } else {
        await _setLegacyCoverProjection(
          state: state,
          coverImageObjectId: imageObjectId,
        );
      }
    });
  }

  Future<void> clearCover({required BookmarkImageRelationState state}) =>
      database.transaction(() async {
        await _editor.save(
          context: state.cover,
          selectedObjectIds: const <int>[],
        );
        await database.customStatement(
          'UPDATE bookmark_photos SET is_cover = 0 WHERE bookmark_id = ?',
          <Object>[state.bookmarkId],
        );
      });

  Future<void> detachImage({
    required BookmarkImageRelationState state,
    required int imageObjectId,
  }) {
    if (!state.images.selectedObjectIds.contains(imageObjectId)) {
      return Future<void>.value();
    }
    return saveImages(
      state: state,
      selectedObjectIds:
          state.images.selectedObjectIds.where((id) => id != imageObjectId),
    );
  }

  /// Mirrors only the legacy-mapped subset required by CoreObjectBridge while
  /// old Photo callers remain. This table is not consulted to decide the user
  /// selection here; it is rewritten from the canonical selection.
  Future<void> _replaceLegacyBookmarkPhotoProjection({
    required BookmarkImageRelationState state,
    required Iterable<int> selectedImageObjectIds,
    required int? coverImageObjectId,
  }) async {
    final selected = selectedImageObjectIds.toList(growable: false);
    final mappedPhotoIds = <int, int>{};
    for (final imageObjectId in selected) {
      final photoId = await _legacyPhotoIdForImage(
        workspaceId: state.workspaceId,
        imageObjectId: imageObjectId,
      );
      if (photoId != null) mappedPhotoIds[imageObjectId] = photoId;
    }

    await database.customStatement(
      'DELETE FROM bookmark_photos WHERE bookmark_id = ?',
      <Object>[state.bookmarkId],
    );
    for (final imageObjectId in selected) {
      final photoId = mappedPhotoIds[imageObjectId];
      if (photoId == null) continue;
      await database.customStatement(
        'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) '
        'VALUES (?, ?, ?)',
        <Object>[
          state.bookmarkId,
          photoId,
          imageObjectId == coverImageObjectId ? 1 : 0,
        ],
      );
    }
  }

  Future<void> _setLegacyCoverProjection({
    required BookmarkImageRelationState state,
    required int coverImageObjectId,
  }) async {
    await database.customStatement(
      'UPDATE bookmark_photos SET is_cover = 0 WHERE bookmark_id = ?',
      <Object>[state.bookmarkId],
    );
    final photoId = await _legacyPhotoIdForImage(
      workspaceId: state.workspaceId,
      imageObjectId: coverImageObjectId,
    );
    if (photoId == null) return;
    await database.customStatement(
      'INSERT OR REPLACE INTO bookmark_photos(bookmark_id, photo_id, is_cover) '
      'VALUES (?, ?, 1)',
      <Object>[state.bookmarkId, photoId],
    );
  }

  Future<int?> _legacyPhotoIdForImage({
    required int workspaceId,
    required int imageObjectId,
  }) async {
    final rows = await database.customSelect(
      '''SELECT photo_id
         FROM photo_object_links
         WHERE workspace_id = ? AND object_id = ?
         LIMIT 1''',
      variables: <Variable<int>>[
        Variable<int>(workspaceId),
        Variable<int>(imageObjectId),
      ],
    ).get();
    if (rows.isEmpty) return null;
    return rows.single.read<int>('photo_id');
  }

  Future<int?> _imageObjectIdForLegacyPhoto({
    required int workspaceId,
    required int photoId,
  }) async {
    final rows = await database.customSelect(
      '''SELECT object_id
         FROM photo_object_links
         WHERE workspace_id = ? AND photo_id = ?
         LIMIT 1''',
      variables: <Variable<int>>[
        Variable<int>(workspaceId),
        Variable<int>(photoId),
      ],
    ).get();
    if (rows.isEmpty) return null;
    return rows.single.read<int>('object_id');
  }

  ObjectPropertyDefinition _relationProperty(
    AppObjectType bookmarkType, {
    required String name,
    required int targetObjectTypeId,
    required bool multiple,
  }) {
    final matches = bookmarkType.properties
        .where((property) => property.name == name)
        .toList(growable: false);
    if (matches.length != 1) {
      throw StateError(
        'Canonical Bookmark ObjectType must contain exactly one $name Relation.',
      );
    }
    final property = matches.single;
    if (!property.isRelation ||
        property.targetObjectTypeId != targetObjectTypeId ||
        property.allowsMultipleRelations != multiple) {
      throw StateError(
        'Canonical Bookmark $name Relation has incompatible target or cardinality.',
      );
    }
    return property;
  }
}

class BookmarkImageRelationState {
  const BookmarkImageRelationState({
    required this.workspaceId,
    required this.bookmarkId,
    required this.bookmarkObjectId,
    required this.images,
    required this.cover,
  });

  final int workspaceId;
  final int bookmarkId;
  final int bookmarkObjectId;
  final RelationSelectionContext images;
  final RelationSelectionContext cover;

  AppObjectType get imageObjectType => images.targetObjectType;
  List<AppObject> get selectedImages => images.selectedObjects;

  /// Returns a cover only when the persisted single Relation is fully healthy.
  /// Corrupt/missing targets stay visible through the Relation contexts and are
  /// never silently repaired by a read.
  int? get validCoverImageObjectId {
    if (cover.hasCardinalityViolation ||
        cover.missingTargetObjectIds.isNotEmpty ||
        cover.selectedObjects.length != 1) {
      return null;
    }
    return cover.selectedObjects.single.id;
  }

  bool get hasDiagnostics =>
      images.missingTargetObjectIds.isNotEmpty ||
      images.hasCardinalityViolation ||
      cover.missingTargetObjectIds.isNotEmpty ||
      cover.hasCardinalityViolation;
}
