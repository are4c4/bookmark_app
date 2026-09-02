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

    final canonicalSourceProperty = sourceType.properties
        .where((property) => property.id == plan.sourceProperty.id)
        .firstOrNull;
    if (canonicalSourceProperty == null || !canonicalSourceProperty.isValue) {
      throw ArgumentError.value(
        plan.sourceProperty.id,
        'plan',
        'Promotion source Property is no longer a persisted Value Property.',
      );
    }

    final sourceObject = (await objectStore.listObjects(sourceType.id))
        .where((object) => object.id == sourceObjectId)
        .firstOrNull;
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
      targetObject = (await objectStore.listObjects(targetType.id))
          .singleWhere((object) => object.id == id);
    } else {
      targetObject = (await objectStore.listObjects(targetType.id))
          .where((object) => object.id == targetObjectId)
          .firstOrNull as AppObject? ??
          (throw ArgumentError.value(
            targetObjectId,
            'targetObjectId',
            'Promotion target Object does not belong to the target ObjectType.',
          ));
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
        relation = refreshedSourceType!.properties
            .singleWhere((property) => property.id == relationId);
      } else {
        _validateSuppliedRelation(
          relation,
          sourceObjectTypeId: sourceType.id,
          targetObjectTypeId: targetType.id,
        );
      }

      final refreshedSource = (await objectStore.listObjects(sourceType.id))
          .singleWhere((object) => object.id == sourceObjectId);
      final currentIds = ObjectRelationValue.fromJson(
        refreshedSource.values[relation.id],
      ).objectIds;
      final nextIds = <int>[...currentIds];
      if (!nextIds.contains(targetObject.id)) nextIds.add(targetObject.id);
      await relationMutations.setRelation(
        objectId: sourceObjectId,
        property: relation,
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
      relationProperty: relation,
      createdTargetObject: createdTargetObject,
      createdRelationProperty: createdRelationProperty,
      sourceValueCleared: sourceValueCleared,
    );
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
