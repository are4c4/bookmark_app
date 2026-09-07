import '../domain/object_model.dart';

class RelationStoredValueInspection {
  const RelationStoredValueInspection._({
    required this.rawObjectIds,
    required this.isMalformed,
  });

  const RelationStoredValueInspection.valid(List<int> rawObjectIds)
      : this._(rawObjectIds: rawObjectIds, isMalformed: false);

  const RelationStoredValueInspection.malformed()
      : this._(rawObjectIds: const <int>[], isMalformed: true);

  final List<int> rawObjectIds;
  final bool isMalformed;

  List<int> get objectIds =>
      ObjectRelationValue(objectIds: rawObjectIds).objectIds;
}

/// Inspects a persisted Relation value without silently discarding malformed
/// data.
///
/// Canonical storage is `null`/an integer for a single Relation and a list for
/// a multi Relation. The legacy `{objectIds: [...]}` envelope and numeric string
/// ids inside lists remain accepted for compatibility because ordinary
/// `ObjectRelationValue.fromJson(...)` has historically accepted them.
RelationStoredValueInspection inspectRelationStoredValue(dynamic value) {
  if (value == null) {
    return const RelationStoredValueInspection.valid(<int>[]);
  }
  if (value is int) {
    return RelationStoredValueInspection.valid(<int>[value]);
  }
  if (value is List) {
    final objectIds = <int>[];
    for (final item in value) {
      final objectId = item is int ? item : int.tryParse('$item');
      if (objectId == null) {
        return const RelationStoredValueInspection.malformed();
      }
      objectIds.add(objectId);
    }
    return RelationStoredValueInspection.valid(
      List<int>.unmodifiable(objectIds),
    );
  }
  if (value is Map && value.containsKey('objectIds')) {
    final rawObjectIds = value['objectIds'];
    if (rawObjectIds is List) {
      return inspectRelationStoredValue(rawObjectIds);
    }
  }
  return const RelationStoredValueInspection.malformed();
}

void assertWellFormedStoredRelationValue(dynamic value) {
  if (inspectRelationStoredValue(value).isMalformed) {
    throw StateError('Stored Relation value is malformed.');
  }
}
