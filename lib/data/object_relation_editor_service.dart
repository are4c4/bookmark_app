import '../domain/object_identity_search.dart';
import '../domain/object_model.dart';
import 'object_identity_search_service.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';
import 'system_object_store.dart';
import 'tag_hierarchy_integrity_service.dart';
import 'tag_object_bridge.dart';

/// Object-owned adapter for Relation picker/editor surfaces.
///
/// Reads always come from [RelationTargetService] so callers see canonical
/// persisted metadata plus diagnostics. Alias-aware candidate search delegates
/// to [ObjectIdentitySearchService] and is intersected back with the canonical
/// candidates loaded for the picker. Canonical Tag targets receive only derived
/// hierarchy-path presentation context; their identity and persistence remain
/// ordinary Object/Relation state. Writes always go through
/// [RelationMutationService] so bidirectional lifecycle/index rules are not
/// reimplemented in UI code.
class ObjectRelationEditorService {
  const ObjectRelationEditorService({
    required this.targets,
    required this.mutations,
    this.identitySearch,
  });

  final RelationTargetService targets;
  final RelationMutationService mutations;
  final ObjectIdentitySearchService? identitySearch;

  Future<RelationSelectionContext> load({
    required int workspaceId,
    required int sourceObjectId,
    required ObjectPropertyDefinition property,
  }) =>
      targets.selectionFor(
        workspaceId: workspaceId,
        sourceObjectId: sourceObjectId,
        property: property,
      );

  /// Searches the canonical target candidates by title or Object alias.
  ///
  /// Search results always carry canonical Object ids. Alias and hierarchy-path
  /// text are display context only. Results are intersected with
  /// [context.candidates] so a stale picker cannot expand beyond the candidate
  /// set that was canonically loaded for this editing session.
  Future<List<ObjectIdentitySearchResult>> searchCandidates({
    required RelationSelectionContext context,
    required String query,
  }) async {
    final search = identitySearch;
    if (search == null) {
      throw StateError('Alias-aware Relation candidate search is not configured.');
    }

    final results = await search.search(
      workspaceId: context.targetObjectType.workspaceId,
      query: query,
      objectTypeId: context.targetObjectType.id,
    );
    final candidateIds = context.candidates.map((object) => object.id).toSet();
    final scoped = results
        .where((result) => candidateIds.contains(result.objectId))
        .toList(growable: false);
    return List.unmodifiable(
      await _withCanonicalTagHierarchyContext(
        context: context,
        results: scoped,
        orderByHierarchy: query.trim().isEmpty,
      ),
    );
  }

  Future<List<ObjectIdentitySearchResult>> _withCanonicalTagHierarchyContext({
    required RelationSelectionContext context,
    required List<ObjectIdentitySearchResult> results,
    required bool orderByHierarchy,
  }) async {
    if (results.isEmpty ||
        context.targetObjectType.kind != ObjectTypeKind.system) {
      return results;
    }

    final systemObjects = SystemObjectStore(
      database: mutations.genericStore.database,
      objectStore: targets.objectStore,
    );
    final systemKey = await systemObjects.systemKeyForObjectType(
      context.targetObjectType.id,
    );
    if (systemKey != TagObjectBridge.systemKey) return results;

    final parentProperties = context.targetObjectType.properties
        .where(
          (property) =>
              property.name == 'Parent' &&
              property.isRelation &&
              property.targetObjectTypeId == context.targetObjectType.id &&
              !property.allowsMultipleRelations,
        )
        .toList(growable: false);
    if (parentProperties.length != 1) {
      throw StateError(
        'Canonical Tag ObjectType must contain exactly one single self-targeting Parent Relation.',
      );
    }

    final snapshot =
        await TagHierarchyIntegrityService(
          objectStore: targets.objectStore,
          relationMutations: mutations,
          relationTargets: targets,
        ).loadSnapshot(
          workspaceId: context.targetObjectType.workspaceId,
          parentProperty: parentProperties.single,
        );
    final tags = await targets.objectStore.listObjects(
      context.targetObjectType.id,
    );
    final tagsById = <int, AppObject>{for (final tag in tags) tag.id: tag};

    final presented = results
        .map(
          (result) => ObjectIdentitySearchResult(
            object: result.object,
            objectType: result.objectType,
            aliases: result.aliases,
            matchedAlias: result.matchedAlias,
            presentationContext: _tagPath(
              objectId: result.objectId,
              snapshot: snapshot,
              tagsById: tagsById,
            ),
          ),
        )
        .toList(growable: false);
    if (orderByHierarchy) {
      presented.sort(
        (left, right) => _compareTagHierarchyOrder(
          leftObjectId: left.objectId,
          rightObjectId: right.objectId,
          snapshot: snapshot,
          tagsById: tagsById,
        ),
      );
    }
    return presented;
  }

  int _compareTagHierarchyOrder({
    required int leftObjectId,
    required int rightObjectId,
    required TagHierarchySnapshot snapshot,
    required Map<int, AppObject> tagsById,
  }) {
    final leftPath = _tagPathObjectIds(
      objectId: leftObjectId,
      snapshot: snapshot,
      tagsById: tagsById,
    );
    final rightPath = _tagPathObjectIds(
      objectId: rightObjectId,
      snapshot: snapshot,
      tagsById: tagsById,
    );
    final sharedLength = leftPath.length < rightPath.length
        ? leftPath.length
        : rightPath.length;
    for (var index = 0; index < sharedLength; index += 1) {
      final left = tagsById[leftPath[index]]!;
      final right = tagsById[rightPath[index]]!;
      final titleOrder = left.title.compareTo(right.title);
      if (titleOrder != 0) return titleOrder;
      final idOrder = left.id.compareTo(right.id);
      if (idOrder != 0) return idOrder;
    }
    return leftPath.length.compareTo(rightPath.length);
  }

  String? _tagPath({
    required int objectId,
    required TagHierarchySnapshot snapshot,
    required Map<int, AppObject> tagsById,
  }) {
    final path = _tagPathObjectIds(
      objectId: objectId,
      snapshot: snapshot,
      tagsById: tagsById,
    );
    if (path.length <= 1) return null;
    return path.map((id) => tagsById[id]!.title).join(' › ');
  }

  List<int> _tagPathObjectIds({
    required int objectId,
    required TagHierarchySnapshot snapshot,
    required Map<int, AppObject> tagsById,
  }) {
    if (!snapshot.parentByTagObjectId.containsKey(objectId)) {
      throw StateError(
        'Canonical Tag picker candidate is missing from the validated hierarchy snapshot.',
      );
    }

    final chain = <int>[];
    int? current = objectId;
    final visited = <int>{};
    while (current != null) {
      if (!visited.add(current)) {
        throw StateError('Canonical Tag hierarchy contains a cycle.');
      }
      if (tagsById[current] == null ||
          !snapshot.parentByTagObjectId.containsKey(current)) {
        throw StateError(
          'Canonical Tag hierarchy references a missing Tag Object.',
        );
      }
      chain.add(current);
      current = snapshot.parentByTagObjectId[current];
    }
    return chain.reversed.toList(growable: false);
  }

  /// Persists an explicit user selection resolved from [load].
  ///
  /// Opening a picker never repairs legacy/corrupt data. Once the user
  /// explicitly saves, selected ids must all be valid candidates and canonical
  /// Property cardinality is enforced before delegating the write.
  Future<void> save({
    required RelationSelectionContext context,
    required Iterable<int> selectedObjectIds,
  }) async {
    final selected = selectedObjectIds.toList(growable: false);
    final candidateIds = context.candidates.map((object) => object.id).toSet();
    final invalid = selected.where((id) => !candidateIds.contains(id)).toList();
    if (invalid.isNotEmpty) {
      throw ArgumentError.value(
        invalid,
        'selectedObjectIds',
        'Relation selection contains Objects outside the canonical target candidates.',
      );
    }
    if (!context.property.allowsMultipleRelations && selected.length > 1) {
      throw ArgumentError.value(
        selected,
        'selectedObjectIds',
        'Single Relation Property cannot store multiple target Objects.',
      );
    }

    await mutations.setRelation(
      objectId: context.sourceObject.id,
      property: context.property,
      targetObjectIds: selected,
    );
  }
}
