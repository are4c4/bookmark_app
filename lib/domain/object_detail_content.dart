import 'object_body.dart';
import 'object_model.dart';

/// Container-agnostic payload for rendering/editing one Object.
///
/// Side peek, center peek, and full-page presentations should all consume the
/// same content payload. Presentation chrome/navigation state deliberately
/// stays outside this model so opening the same Object never forks its data.
class ObjectDetailContent {
  const ObjectDetailContent({
    required this.object,
    required this.objectType,
    this.body = const ObjectBodyDocument(),
    this.computedValues = const <int, dynamic>{},
  });

  final AppObject object;
  final AppObjectType objectType;
  final ObjectBodyDocument body;

  /// Derived Formula/Rollup values can be supplied by the caller without being
  /// persisted into the Object's ordinary value map.
  final Map<int, dynamic> computedValues;

  dynamic valueFor(ObjectPropertyDefinition property) {
    if (property.isComputed) return computedValues[property.id];
    return object.valueFor(property.id);
  }

  ObjectDetailContent copyWith({
    AppObject? object,
    AppObjectType? objectType,
    ObjectBodyDocument? body,
    Map<int, dynamic>? computedValues,
  }) {
    return ObjectDetailContent(
      object: object ?? this.object,
      objectType: objectType ?? this.objectType,
      body: body ?? this.body,
      computedValues: computedValues ?? this.computedValues,
    );
  }
}
