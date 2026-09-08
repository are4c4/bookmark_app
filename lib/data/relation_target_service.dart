import '../domain/object_model.dart';
import 'object_store.dart';
import 'relation_read_service.dart';
import 'relation_stored_value_inspector.dart';

class RelationTargetCandidates {
  const RelationTargetCandidates({
    required this.property,
    required this.targetObjectType,
    required this.objects,
  });

  final ObjectPropertyDefinition property;
  final AppObjectType targetObjectType;
  final List<AppObject> objects;
}

class RelationSelectionContext {
  const RelationSelectionContext({
    required this.sourceObject,
    required this.property,
    required this.targetObjectType,
    required this.candidates,
    required this.selectedObjectIds,
    required this.selectedObjects,
    required this.missingTargetObjectIds,
    required this.hasCardinalityViolation,
  });

  final AppObject sourceObject;
  final ObjectPropertyDefinition property;
  final AppObjectType targetObjectType;
  final List<AppObject> candidates;
  final List<int> selectedObjectIds;
  final List<AppObject> selectedObjects;
  final List<int> missingTargetObjectIds;
  final bool hasCardinalityViolation;
}

/// Resolves persisted Relation metadata and valid target Objects for UI pickers
/// without trusting stale caller config.
class RelationTargetService {
  const RelationTargetService(this.objectStore);

  final ObjectStore objectStore;

  Future<RelationTargetCandidates> candidatesFor({
    required int workspaceId,
    required ObjectPropertyDefinition property,
  }) async {
    final sourceType = await objectStore.getObjectType(property.objectTypeId);
    if (sourceType == null || sourceType.workspaceId != workspaceId) {
      throw ArgumentError.value(
        property.objectTypeId,
        'property',
        'Relation source ObjectType does not exist in the requested workspace.',
      );
    }

    ObjectPropertyDefinition? storedProperty;
    for (final candidate in sourceType.properties) {
      if (candidate.id == property.id) {
        storedProperty = candidate;
        break;
      }
    }
    if (storedProperty == null || !storedProperty.isRelation) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Property is not a persisted Relation Property of its source ObjectType.',
      );
    }

    final targetTypeId = storedProperty.targetObjectTypeId;
    if (targetTypeId == null) {
      throw StateError(
        'Relation Property ${storedProperty.name} has no target ObjectType.',
      );
    }
    final targetType = await objectStore.getObjectType(targetTypeId);
    if (targetType == null) {
      throw StateError(
        'Relation Property ${storedProperty.name} targets a missing ObjectType.',
      );
    }
    if (targetType.workspaceId != workspaceId) {
      throw StateError(
        'Relation Property ${storedProperty.name} targets another workspace.',
      );
    }

    final objects = await objectStore.listObjects(targetTypeId);
    return RelationTargetCandidates(
      property: storedProperty,
      targetObjectType: targetType,
      objects: List.unmodifiable(objects),
    );
  }

  /// Loads everything a Relation picker needs from canonical persisted state.
  ///
  /// Missing target ids and legacy single-cardinality violations are surfaced
  /// as diagnostics only. This method never mutates or silently drops values.
  Future<RelationSelectionContext> selectionFor({
    required int workspaceId,
    required int sourceObjectId,
    required ObjectPropertyDefinition property,
  }) async {
    final resolved = await candidatesFor(
      workspaceId: workspaceId,
      property: property,
    );

    final sourceObjects = await objectStore.listObjects(
      resolved.property.objectTypeId,
    );
    AppObject? sourceObject;
    for (final candidate in sourceObjects) {
      if (candidate.id == sourceObjectId) {
        sourceObject = candidate;
        break;
      }
    }
    if (sourceObject == null) {
      throw ArgumentError.value(
        sourceObjectId,
        'sourceObjectId',
        'Relation source Object does not belong to the persisted source ObjectType.',
      );
    }

    final inspection = inspectRelationStoredValue(
      sourceObject.values[resolved.property.id],
    );
    if (inspection.isMalformed) {
      throw StateError(
        'Malformed persisted Relation value for Object ${sourceObject.id} / Relation Property ${resolved.property.id}.',
      );
    }
    final selectedObjectIds = inspection.rawObjectIds;
    final candidatesById = <int, AppObject>{
      for (final candidate in resolved.objects) candidate.id: candidate,
    };
    final selectedObjects = <AppObject>[];
    final missingTargetObjectIds = <int>[];
    for (final targetId in selectedObjectIds) {
      final target = candidatesById[targetId];
      if (target == null) {
        missingTargetObjectIds.add(targetId);
      } else {
        selectedObjects.add(target);
      }
    }

    return RelationSelectionContext(
      sourceObject: sourceObject,
      property: resolved.property,
      targetObjectType: resolved.targetObjectType,
      candidates: List.unmodifiable(resolved.objects),
      selectedObjectIds: List.unmodifiable(selectedObjectIds),
      selectedObjects: List.unmodifiable(selectedObjects),
      missingTargetObjectIds: List.unmodifiable(missingTargetObjectIds),
      hasCardinalityViolation: !resolved.property.allowsMultipleRelations &&
          selectedObjectIds.length > 1,
    );
  }

  /// Reloads one Relation selection for an integrity-sensitive mutation.
  ///
  /// Unlike [selectionFor], this is deliberately fail-closed: the persisted
  /// value must be well-formed, every target must still exist in the declared
  /// target ObjectType, cardinality must be valid, and the normalized edge
  /// projection must exactly match stored target ids/order/positions. It never
  /// repairs either side. Diagnostic picker surfaces should keep using
  /// [selectionFor] so corruption remains visible until an explicit integrity
  /// workflow handles it.
  Future<RelationSelectionContext> selectionForMutation({
    required int workspaceId,
    required int sourceObjectId,
    required ObjectPropertyDefinition property,
  }) async {
    final context = await selectionFor(
      workspaceId: workspaceId,
      sourceObjectId: sourceObjectId,
      property: property,
    );
    if (context.missingTargetObjectIds.isNotEmpty ||
        context.hasCardinalityViolation) {
      throw StateError(
        'Persisted Relation targets or cardinality are inconsistent for mutation.',
      );
    }

    final propertyEdges = (await objectStore.outgoingRelations(sourceObjectId))
        .where((edge) => edge.propertyId == context.property.id)
        .toList(growable: false);
    if (!relationStoredValueMatchesEdges(
      source: context.sourceObject,
      property: context.property,
      edges: propertyEdges,
    )) {
      throw StateError(
        'Persisted Relation value does not match its normalized edge index.',
      );
    }

    return context;
  }
}
