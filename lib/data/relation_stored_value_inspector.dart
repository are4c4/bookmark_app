import '../domain/object_model.dart';

class RelationStoredValueInspection {
  const RelationStoredValueInspection({
    required this.value,
    required this.rawObjectIds,
    required this.isMalformed,
  });

  final ObjectRelationValue value;
  final List<int> rawObjectIds;
  final bool isMalformed;
}

/// Strictly inspects persisted Relation storage without changing ordinary
/// semantic reads. `ObjectRelationValue.fromJson(...)` intentionally remains
/// permissive for compatibility, while integrity-sensitive paths can fail
/// closed instead of silently dropping malformed stored input.
RelationStoredValueInspection inspectRelationStoredValue(dynamic rawValue) {
  if (rawValue == null) {
    return const RelationStoredValueInspection(
      value: ObjectRelationValue(objectIds: <int>[]),
      rawObjectIds: <int>[],
      isMalformed: false,
    );
  }

  if (rawValue is int) {
    return RelationStoredValueInspection(
      value: ObjectRelationValue.single(rawValue),
      rawObjectIds: <int>[rawValue],
      isMalformed: false,
    );
  }

  if (rawValue is List) {
    final objectIds = <int>[];
    var malformed = false;
    for (final item in rawValue) {
      if (item is int) {
        objectIds.add(item);
        continue;
      }
      if (item is String) {
        final parsed = int.tryParse(item);
        if (parsed != null) {
          objectIds.add(parsed);
          continue;
        }
      }
      malformed = true;
    }
    return RelationStoredValueInspection(
      value: ObjectRelationValue(objectIds: objectIds),
      rawObjectIds: List<int>.unmodifiable(objectIds),
      isMalformed: malformed,
    );
  }

  if (rawValue is Map) {
    if (!rawValue.containsKey('objectIds') || rawValue['objectIds'] is! List) {
      return const RelationStoredValueInspection(
        value: ObjectRelationValue(objectIds: <int>[]),
        rawObjectIds: <int>[],
        isMalformed: true,
      );
    }
    return inspectRelationStoredValue(rawValue['objectIds']);
  }

  return const RelationStoredValueInspection(
    value: ObjectRelationValue(objectIds: <int>[]),
    rawObjectIds: <int>[],
    isMalformed: true,
  );
}

void assertRelationStoredValueWellFormed(
  dynamic rawValue, {
  required String context,
}) {
  if (inspectRelationStoredValue(rawValue).isMalformed) {
    throw StateError('Malformed persisted Relation value for $context.');
  }
}
