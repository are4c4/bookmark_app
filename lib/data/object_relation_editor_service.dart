import '../domain/object_model.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';

/// Object-owned adapter for Relation picker/editor surfaces.
///
/// Reads always come from [RelationTargetService] so callers see canonical
/// persisted metadata plus diagnostics. Writes always go through
/// [RelationMutationService] so bidirectional lifecycle/index rules are not
/// reimplemented in UI code.
class ObjectRelationEditorService {
  const ObjectRelationEditorService({
    required this.targets,
    required this.mutations,
  });

  final RelationTargetService targets;
  final RelationMutationService mutations;

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
