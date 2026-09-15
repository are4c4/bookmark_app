import '../../../domain/object_detail_property_presentation.dart';

/// Shared presentation policy for deciding whether an Object Property may be
/// collapsed behind the empty-Property reveal affordance.
///
/// Relation and computed Properties deliberately stay visible because their
/// canonical empty-state semantics are not equivalent to an absent scalar
/// value. Hidden Properties are handled by the existing visibility contract.
class ObjectDetailEmptyPropertyPolicy {
  const ObjectDetailEmptyPropertyPolicy._();

  static bool isCollapsibleEmpty(
    ObjectDetailPropertyPresentation presentation,
  ) {
    if (presentation.isHidden ||
        presentation.usesRelationRenderer ||
        presentation.isComputed) {
      return false;
    }

    final value = presentation.value;
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }
}
