enum ObjectFilterOperator {
  equals,
  notEquals,
  contains,
  notContains,
  isEmpty,
  isNotEmpty,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  before,
  after,
  containsAny,
  containsAll,
}

enum ObjectHierarchyMatchMode { exact, isOrBelow, belowOnly, excludeBranch }

enum ObjectSortDirection {
  ascending,
  descending,
}

class ObjectFilterRule {
  const ObjectFilterRule({
    required this.propertyId,
    required this.operator,
    this.value,
    this.hierarchyMatchMode = ObjectHierarchyMatchMode.exact,
  });

  /// `null` targets the Object title. Otherwise this is a PropertyDefinition id.
  final int? propertyId;
  final ObjectFilterOperator operator;
  final dynamic value;

  /// Optional hierarchy semantics for relation-valued filters.
  ///
  /// Existing saved rules omit this field and therefore remain exact. Callers
  /// must provide a canonical hierarchy matcher before non-exact modes can
  /// evaluate; the query engine otherwise fails closed.
  final ObjectHierarchyMatchMode hierarchyMatchMode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'propertyId': propertyId,
        'operator': operator.name,
        if (value != null) 'value': value,
        if (hierarchyMatchMode != ObjectHierarchyMatchMode.exact)
          'hierarchyMatchMode': hierarchyMatchMode.name,
      };

  static ObjectFilterRule? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final operatorName = '${raw['operator'] ?? ''}';
    ObjectFilterOperator? operator;
    for (final candidate in ObjectFilterOperator.values) {
      if (candidate.name == operatorName) {
        operator = candidate;
        break;
      }
    }
    if (operator == null) return null;

    var hierarchyMatchMode = ObjectHierarchyMatchMode.exact;
    final hierarchyModeName = raw['hierarchyMatchMode'];
    if (hierarchyModeName != null) {
      ObjectHierarchyMatchMode? decodedMode;
      for (final candidate in ObjectHierarchyMatchMode.values) {
        if (candidate.name == '$hierarchyModeName') {
          decodedMode = candidate;
          break;
        }
      }
      if (decodedMode == null) return null;
      hierarchyMatchMode = decodedMode;
    }

    final propertyRaw = raw['propertyId'];
    final propertyId = propertyRaw == null
        ? null
        : propertyRaw is int
            ? propertyRaw
            : int.tryParse('$propertyRaw');
    return ObjectFilterRule(
      propertyId: propertyId,
      operator: operator,
      value: raw['value'],
      hierarchyMatchMode: hierarchyMatchMode,
    );
  }
}

class ObjectSortRule {
  const ObjectSortRule({
    required this.propertyId,
    required this.direction,
  });

  /// `null` sorts by Object title.
  final int? propertyId;
  final ObjectSortDirection direction;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'propertyId': propertyId,
        'direction': direction.name,
      };

  static ObjectSortRule? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final directionName = '${raw['direction'] ?? ''}';
    ObjectSortDirection? direction;
    for (final candidate in ObjectSortDirection.values) {
      if (candidate.name == directionName) {
        direction = candidate;
        break;
      }
    }
    if (direction == null) return null;
    final propertyRaw = raw['propertyId'];
    final propertyId = propertyRaw == null
        ? null
        : propertyRaw is int
            ? propertyRaw
            : int.tryParse('$propertyRaw');
    return ObjectSortRule(propertyId: propertyId, direction: direction);
  }
}
