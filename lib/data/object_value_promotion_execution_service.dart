import '../domain/object_model.dart';
import '../domain/object_value_promotion.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';

class ObjectValuePromotionExecutionResult {
  const ObjectValuePromotionExecutionResult({
    required this.targetObject,
    required this.relationProperty,
    required this.createdTargetObject,
    required this.createdRelationProperty,
    required this.sourceValueCleared,
  });

  final AppObject targetObject;
  final ObjectPropertyDefinition relationProperty;
  final bool createdTargetObject;
  final bool createdRelationProperty;
  final bool sourceValueCleared;
}

/// Executes a previously-reviewed Value -> Object promotion plan.
///
/// The source scalar is preserved by default. A destructive clear is only
/// allowed when the plan requests it and the caller explicitly confirms it.
/// Relation writes are delegated to [RelationMutationService] so canonical
/// source/target validation and bidirectional lifecycle rules remain centralized
/// in the Relation lane.
class ObjectValuePromotionExecutionService {
  const ObjectValuePromotionExecutionService({
    required this.objectStore,
    required this.relationMutations,
  });

  final ObjectStore objectStore;
  final RelationMutationService relationMutations;

  Future<ObjectValuePromotionExecutionResult> execute({
    required ObjectValuePromotionPlan plan,
    required int sourceObjectId,
    int? targetObjectId,
    ObjectPropertyDefinition? relationProperty,
    bool destructiveSourceClearConfirmed = false,
  }) async {
    if (plan.requiresDestructiveConfirmation &&
        !destructiveSourceClearConfirmed) {
      throw StateError(
        'Clearing the source Value requires explicit destructive confirmation.',
      );
    }

    final sourceType = await objectStore.getObjectType(
      plan.sourceProperty.objectTypeId,
    );
    final targetType = await objectStore.getObjectType(plan.targetObjectTypeId);
    if (sourceType == null || targetType == null) {
      throw ArgumentError('Promotion source and target ObjectTypes must exist.');
    }
    if (sourceType.workspaceId != targetType.workspaceId) {
      throw ArgumentError(
        'Promotion source and target ObjectTypes must belong to the same workspace.',
      );
    }

    final canonicalSourceProperty = _propertyById(
      sourceType.properties,
      plan.sourceProperty.id,
    );
    if (canonicalSourceProperty == null || !canonicalSourceProperty.isValue) {
      throw ArgumentError.value(
        plan.sourceProperty.id,
        'plan',
        'Promotion source Property is no longer a persisted Value Property.',
      );
    }

    final sourceObject = await _objectById(sourceType.id, sourceObjectId);
    if (sourceObject == null) {
      throw ArgumentError.value(
        sourceObjectId,
        'sourceObjectId',
        'Promotion source Object does not exist in the source ObjectType.',
      );
    }
    if (!_valuesEqual(
      sourceObject.values[canonicalSourceProperty.id],
      plan.sourceValue,
    )) {
      throw StateError(
        'Promotion plan is stale because the source Value changed after planning.',
      );
    }

    var createdTargetObject = false;
    AppObject targetObject;
    if (targetObjectId == null) {
      final id = await objectStore.createObject(
        objectTypeId: targetType.id,
        title: plan.targetObjectTitle,
      );
      createdTargetObject = true;
      targetObject = (await _objectById(targetType.id, id))!;
    } else {
      final existingTarget = await _objectById(targetType.id, targetObjectId);
      if (existingTarget == null) {
        throw ArgumentError.value(
          targetObjectId,
          'targetObjectId',
          'Promotion target Object does not belong to the target ObjectType.',
        );
      }
      targetObject = existingTarget;
    }

    var createdRelationProperty = false;
    ObjectPropertyDefinition? relation = relationProperty;
    try {
      relation ??= _matchingRelation(
        sourceType.properties,
        plan.relationPropertyName,
        targetType.id,
      );
      if (relation == null) {
        final conflicting = sourceType.properties.any(
          (property) => property.name == plan.relationPropertyName,
        );
        if (conflicting) {
          throw StateError(
            'A non-compatible Property already uses the planned Relation name.',
          );
        }
        final relationId = await objectStore.createRelationProperty(
          objectTypeId: sourceType.id,
          name: plan.relationPropertyName,
          targetObjectTypeId: targetType.id,
          multiple: true,
        );
        createdRelationProperty = true;
        final refreshedSourceType = await objectStore.getObjectType(sourceType.id);
        relation = _propertyById(refreshedSourceType!.properties, relationId)!;
      } else {
        _validateSuppliedRelation(
          relation,
          sourceObjectTypeId: sourceType.id,
          targetObjectTypeId: targetType.id,
        );
      }

      final linkedRelation = relation!;
      final refreshedSource = (await _objectById(sourceType.id, sourceObjectId))!;
      final currentIds = ObjectRelationValue.fromJson(
        refreshedSource.values[linkedRelation.id],
      ).objectIds;
      final nextIds = <int>[...currentIds];
      if (!nextIds.contains(targetObject.id)) nextIds.add(targetObject.id);
      await relationMutations.setRelation(
        objectId: sourceObjectId,
        property: linkedRelation,
        targetObjectIds: nextIds,
      );
    } catch (_) {
      if (createdRelationProperty && relation != null) {
        await objectStore.deleteProperty(relation.id);
      }
      if (createdTargetObject) {
        await objectStore.deleteObject(targetObject.id);
      }
      rethrow;
    }

    final linkedRelation = relation!;
    var sourceValueCleared = false;
    if (plan.sourceDisposition ==
        ObjectValuePromotionSourceDisposition.clearAfterLink) {
      await objectStore.setPropertyValue(
        objectId: sourceObjectId,
        property: canonicalSourceProperty,
        value: null,
      );
      sourceValueCleared = true;
    }

    return ObjectValuePromotionExecutionResult(
      targetObject: targetObject,
      relationProperty: linkedRelation,
      createdTargetObject: createdTargetObject,
      createdRelationProperty: createdRelationProperty,
      sourceValueCleared: sourceValueCleared,
    );
  }

  Future<AppObject?> _objectById(int objectTypeId, int objectId) async {
    for (final object in await objectStore.listObjects(objectTypeId)) {
      if (object.id == objectId) return object;
    }
    return null;
  }

  ObjectPropertyDefinition? _propertyById(
    List<ObjectPropertyDefinition> properties,
    int propertyId,
  ) {
    for (final property in properties) {
      if (property.id == propertyId) return property;
    }
    return null;
  }

  ObjectPropertyDefinition? _matchingRelation(
    List<ObjectPropertyDefinition> properties,
    String name,
    int targetObjectTypeId,
  ) {
    for (final property in properties) {
      if (property.name == name &&
          property.isRelation &&
          property.targetObjectTypeId == targetObjectTypeId) {
        return property;
      }
    }
    return null;
  }

  void _validateSuppliedRelation(
    ObjectPropertyDefinition property, {
    required int sourceObjectTypeId,
    required int targetObjectTypeId,
  }) {
    if (!property.isRelation ||
        property.objectTypeId != sourceObjectTypeId ||
        property.targetObjectTypeId != targetObjectTypeId) {
      throw ArgumentError.value(
        property.id,
        'relationProperty',
        'Promotion Relation does not connect the planned source and target ObjectTypes.',
      );
    }
  }

  bool _valuesEqual(dynamic left, dynamic right) {
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_valuesEqual(left[index], right[index])) return false;
      }
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final entry in left.entries) {
        if (!right.containsKey(entry.key) ||
            !_valuesEqual(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }
}
