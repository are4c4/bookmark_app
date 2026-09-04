import '../domain/object_identity_search.dart';
import '../domain/object_model.dart';
import 'object_identity_search_service.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';

/// Object-owned adapter for Relation picker/editor surfaces.
///
/// Reads always come from [RelationTargetService] so callers see canonical
/// persisted metadata plus diagnostics. Alias-aware candidate search delegates
/// to [ObjectIdentitySearchService] and is intersected back with the canonical
/// candidates loaded for the picker. Writes always go through
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
  /// Search results always carry canonical Object ids. Alias text is display
  /// context only. Results are intersected with [context.candidates] so a stale
  /// picker cannot expand beyond the candidate set that was canonically loaded
  /// for this editing session.
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
    return List.unmodifiable(
      results.where((result) => candidateIds.contains(result.objectId)),
    );
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
    final selected = selectedObjectIds.toSet().toList(growable: false);
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
