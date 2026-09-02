import '../domain/object_model.dart';
import 'object_store.dart';

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

/// Resolves the persisted Relation Property and its valid target Objects for UI
/// pickers without trusting stale caller config.
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
}
