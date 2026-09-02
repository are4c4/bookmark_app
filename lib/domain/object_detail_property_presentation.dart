import 'object_detail_content.dart';
import 'object_model.dart';

class ObjectDetailPropertyPresentation {
  const ObjectDetailPropertyPresentation({
    required this.property,
    required this.value,
    required this.displayText,
    required this.isHidden,
  });

  final ObjectPropertyDefinition property;
  final dynamic value;

  /// Null for Relations because they should render canonical resolved Object
  /// chips rather than serialized ids from the Value map.
  final String? displayText;
  final bool isHidden;

  bool get usesRelationRenderer => property.isRelation;
  bool get isComputed => property.isComputed;
}

/// Container-agnostic Property presentation shared by full-page/side/center
/// Object detail surfaces.
///
/// Relation rendering deliberately stays separate so callers use canonical
/// Relation neighborhood data rather than formatting persisted target ids.
class ObjectDetailPropertyPresenter {
  const ObjectDetailPropertyPresenter();

  ObjectDetailPropertyPresentation present({
    required ObjectDetailContent content,
    required ObjectPropertyDefinition property,
  }) {
    final value = content.valueFor(property);
    return ObjectDetailPropertyPresentation(
      property: property,
      value: value,
      displayText: property.isRelation ? null : formatValue(value),
      isHidden: property.config['hidden'] == true,
    );
  }

  String formatValue(dynamic value) {
    if (value == null) return 'なし';
    if (value is List) return value.join(', ');
    if (value is bool) return value ? 'はい' : 'いいえ';
    return '$value';
  }
}
