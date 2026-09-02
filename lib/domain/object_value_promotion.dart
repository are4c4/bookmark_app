import 'object_model.dart';

enum ObjectValuePromotionSourceDisposition {
  preserve,
  clearAfterLink,
}

/// A side-effect-free description of promoting a lightweight Property value
/// into a first-class Object and linking back to it with an Object Relation.
///
/// Execution is intentionally separate from planning so UI can preview the
/// conversion, resolve ambiguity, and preserve the original scalar value until
/// the Object and Relation write both succeed.
class ObjectValuePromotionPlan {
  const ObjectValuePromotionPlan({
    required this.sourceProperty,
    required this.sourceValue,
    required this.targetObjectTypeId,
    required this.targetObjectTitle,
    required this.relationPropertyName,
    this.sourceDisposition = ObjectValuePromotionSourceDisposition.preserve,
  });

  final ObjectPropertyDefinition sourceProperty;
  final dynamic sourceValue;
  final int targetObjectTypeId;
  final String targetObjectTitle;
  final String relationPropertyName;
  final ObjectValuePromotionSourceDisposition sourceDisposition;

  bool get preservesSourceValue =>
      sourceDisposition == ObjectValuePromotionSourceDisposition.preserve;

  /// Clearing the scalar is deliberately treated as a potentially lossy action
  /// even when the target Object has been created successfully.
  bool get requiresDestructiveConfirmation => !preservesSourceValue;
}

class ObjectValuePromotionPlanner {
  const ObjectValuePromotionPlanner();

  ObjectValuePromotionPlan plan({
    required ObjectPropertyDefinition sourceProperty,
    required dynamic sourceValue,
    required int targetObjectTypeId,
    required String targetObjectTitle,
    required String relationPropertyName,
    ObjectValuePromotionSourceDisposition sourceDisposition =
        ObjectValuePromotionSourceDisposition.preserve,
  }) {
    if (!sourceProperty.isValue) {
      throw ArgumentError.value(
        sourceProperty.type,
        'sourceProperty',
        'Only Value properties can be promoted to Objects.',
      );
    }
    if (sourceValue == null) {
      throw ArgumentError.value(
        sourceValue,
        'sourceValue',
        'A null value cannot be promoted.',
      );
    }
    if (targetObjectTypeId <= 0) {
      throw ArgumentError.value(
        targetObjectTypeId,
        'targetObjectTypeId',
        'Target ObjectType id must be positive.',
      );
    }
    if (targetObjectTitle.trim().isEmpty) {
      throw ArgumentError.value(
        targetObjectTitle,
        'targetObjectTitle',
        'Target Object title cannot be empty.',
      );
    }
    if (relationPropertyName.trim().isEmpty) {
      throw ArgumentError.value(
        relationPropertyName,
        'relationPropertyName',
        'Relation Property name cannot be empty.',
      );
    }

    return ObjectValuePromotionPlan(
      sourceProperty: sourceProperty,
      sourceValue: sourceValue,
      targetObjectTypeId: targetObjectTypeId,
      targetObjectTitle: targetObjectTitle.trim(),
      relationPropertyName: relationPropertyName.trim(),
      sourceDisposition: sourceDisposition,
    );
  }
}
