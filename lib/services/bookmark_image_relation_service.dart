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
import '../domain/object_identity_search.dart';
import '../domain/object_model.dart';

/// Canonical Bookmark -> Image editing boundary used while legacy Photo data is
/// still retained for compatibility.
///
/// This service never writes `bookmark_photos` or `photos`. It resolves a legacy
/// Bookmark to its mirrored canonical Object, validates the system `Images` and
/// `Cover Image` Relation schema, then delegates reads/search/writes to the
/// shared Object/Relation services.
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

  /// Returns null only when this legacy Bookmark has not yet been mirrored into
  /// the canonical Object system. A partially present or incompatible canonical
  /// schema fails closed instead of silently falling back to a second write path.
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

    await database.transaction(() async {
      if (currentCoverId != null && !selectedSet.contains(currentCoverId)) {
        await _editor.save(
          context: state.cover,
          selectedObjectIds: const <int>[],
        );
      }
      await _editor.save(
        context: state.images,
        selectedObjectIds: selected,
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
    });
  }

  Future<void> clearCover({required BookmarkImageRelationState state}) =>
      _editor.save(
        context: state.cover,
        selectedObjectIds: const <int>[],
      );

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
