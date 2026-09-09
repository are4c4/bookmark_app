import '../domain/object_model.dart';
import '../domain/object_query.dart';

typedef ObjectQueryValueResolver = dynamic Function(
  AppObject object,
  int? propertyId,
);

/// Returns whether [descendantObjectId] is a strict descendant of
/// [ancestorObjectId] in a canonical hierarchy snapshot.
///
/// Query code intentionally receives this as a read-only matcher so hierarchy
/// persistence/traversal stays owned by the canonical Relation subsystem.
typedef ObjectHierarchyDescendantMatcher = bool Function(
  int descendantObjectId,
  int ancestorObjectId,
);

class ObjectQueryEngine {
  const ObjectQueryEngine();

  List<AppObject> apply({
    required Iterable<AppObject> objects,
    List<ObjectFilterRule> filters = const <ObjectFilterRule>[],
    List<ObjectSortRule> sorts = const <ObjectSortRule>[],
    ObjectQueryValueResolver? valueResolver,
    ObjectHierarchyDescendantMatcher? hierarchyDescendantMatcher,
  }) {
    final resolve = valueResolver ?? _defaultValueResolver;
    final result = objects
        .where(
          (object) => filters.every(
            (rule) => _matches(
              resolve(object, rule.propertyId),
              rule,
              hierarchyDescendantMatcher,
            ),
          ),
        )
        .toList(growable: true);

    if (sorts.isNotEmpty) {
      result.sort((left, right) {
        for (final rule in sorts) {
          final comparison = _compareValues(
            resolve(left, rule.propertyId),
            resolve(right, rule.propertyId),
          );
          if (comparison == 0) continue;
          return rule.direction == ObjectSortDirection.ascending
              ? comparison
              : -comparison;
        }
        return left.id.compareTo(right.id);
      });
    }
    return result;
  }

  dynamic _defaultValueResolver(AppObject object, int? propertyId) =>
      propertyId == null ? object.title : object.values[propertyId];

  bool _matches(
    dynamic actual,
    ObjectFilterRule rule,
    ObjectHierarchyDescendantMatcher? hierarchyDescendantMatcher,
  ) {
    if (rule.hierarchyMatchMode != ObjectHierarchyMatchMode.exact) {
      return _matchesHierarchy(actual, rule, hierarchyDescendantMatcher);
    }

    return switch (rule.operator) {
      ObjectFilterOperator.equals => _equals(actual, rule.value),
      ObjectFilterOperator.notEquals => !_equals(actual, rule.value),
      ObjectFilterOperator.contains => _contains(actual, rule.value),
      ObjectFilterOperator.notContains => !_contains(actual, rule.value),
      ObjectFilterOperator.isEmpty => _isEmpty(actual),
      ObjectFilterOperator.isNotEmpty => !_isEmpty(actual),
      ObjectFilterOperator.greaterThan => _ordered(
        actual,
        rule.value,
        (v) => v > 0,
      ),
      ObjectFilterOperator.greaterThanOrEqual => _ordered(
        actual,
        rule.value,
        (v) => v >= 0,
      ),
      ObjectFilterOperator.lessThan => _ordered(
        actual,
        rule.value,
        (v) => v < 0,
      ),
      ObjectFilterOperator.lessThanOrEqual => _ordered(
        actual,
        rule.value,
        (v) => v <= 0,
      ),
      ObjectFilterOperator.before => _dateCompare(
        actual,
        rule.value,
        (v) => v < 0,
      ),
      ObjectFilterOperator.after => _dateCompare(
        actual,
        rule.value,
        (v) => v > 0,
      ),
      ObjectFilterOperator.containsAny => _containsAny(actual, rule.value),
      ObjectFilterOperator.containsAll => _containsAll(actual, rule.value),
    };
  }

  bool _matchesHierarchy(
    dynamic actual,
    ObjectFilterRule rule,
    ObjectHierarchyDescendantMatcher? hierarchyDescendantMatcher,
  ) {
    if (hierarchyDescendantMatcher == null) return false;
    if (rule.operator != ObjectFilterOperator.containsAny &&
        rule.operator != ObjectFilterOperator.containsAll) {
      return false;
    }

    final actualIds = _asObjectIds(actual);
    final expectedIds = _asObjectIds(rule.value);
    if (expectedIds.isEmpty) return false;

    bool isInBranch(int actualId, int expectedId) =>
        actualId == expectedId ||
        hierarchyDescendantMatcher(actualId, expectedId);

    bool isStrictlyBelow(int actualId, int expectedId) =>
        actualId != expectedId &&
        hierarchyDescendantMatcher(actualId, expectedId);

    switch (rule.hierarchyMatchMode) {
      case ObjectHierarchyMatchMode.exact:
        return false;
      case ObjectHierarchyMatchMode.isOrBelow:
        return _matchesHierarchyBranches(
          actualIds,
          expectedIds,
          rule.operator,
          isInBranch,
        );
      case ObjectHierarchyMatchMode.belowOnly:
        return _matchesHierarchyBranches(
          actualIds,
          expectedIds,
          rule.operator,
          isStrictlyBelow,
        );
      case ObjectHierarchyMatchMode.excludeBranch:
        return !expectedIds.any(
          (expectedId) =>
              actualIds.any((actualId) => isInBranch(actualId, expectedId)),
        );
    }
  }

  bool _matchesHierarchyBranches(
    List<int> actualIds,
    List<int> expectedIds,
    ObjectFilterOperator operator,
    bool Function(int actualId, int expectedId) matchesBranch,
  ) {
    if (actualIds.isEmpty) return false;
    if (operator == ObjectFilterOperator.containsAll) {
      return expectedIds.every(
        (expectedId) =>
            actualIds.any((actualId) => matchesBranch(actualId, expectedId)),
      );
    }
    return expectedIds.any(
      (expectedId) =>
          actualIds.any((actualId) => matchesBranch(actualId, expectedId)),
    );
  }

  bool _equals(dynamic actual, dynamic expected) {
    if (actual is num && expected is num) return actual == expected;
    if (actual is bool || expected is bool) return actual == expected;
    if (actual is Iterable || expected is Iterable) {
      final a = _asComparableList(actual);
      final b = _asComparableList(expected);
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_equals(a[i], b[i])) return false;
      }
      return true;
    }
    return '${actual ?? ''}'.toLowerCase() == '${expected ?? ''}'.toLowerCase();
  }

  bool _contains(dynamic actual, dynamic expected) {
    if (actual == null || expected == null) return false;
    if (actual is Iterable) {
      return actual.any((item) => _equals(item, expected));
    }
    return '$actual'.toLowerCase().contains('$expected'.toLowerCase());
  }

  bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  bool _ordered(dynamic actual, dynamic expected, bool Function(int) accept) {
    final leftNumber = _asNumber(actual);
    final rightNumber = _asNumber(expected);
    if (leftNumber != null && rightNumber != null) {
      return accept(leftNumber.compareTo(rightNumber));
    }
    if (actual == null || expected == null) return false;
    return accept('$actual'.toLowerCase().compareTo('$expected'.toLowerCase()));
  }

  bool _dateCompare(dynamic actual, dynamic expected, bool Function(int) accept) {
    final left = _asDate(actual);
    final right = _asDate(expected);
    if (left == null || right == null) return false;
    return accept(left.compareTo(right));
  }

  bool _containsAny(dynamic actual, dynamic expected) {
    final actualValues = _asComparableList(actual);
    final expectedValues = _asComparableList(expected);
    if (actualValues.isEmpty || expectedValues.isEmpty) return false;
    return expectedValues.any(
      (expectedItem) =>
          actualValues.any((actualItem) => _equals(actualItem, expectedItem)),
    );
  }

  bool _containsAll(dynamic actual, dynamic expected) {
    final actualValues = _asComparableList(actual);
    final expectedValues = _asComparableList(expected);
    if (expectedValues.isEmpty) return true;
    return expectedValues.every(
      (expectedItem) =>
          actualValues.any((actualItem) => _equals(actualItem, expectedItem)),
    );
  }

  int _compareValues(dynamic left, dynamic right) {
    final leftEmpty = _isEmpty(left);
    final rightEmpty = _isEmpty(right);
    if (leftEmpty && rightEmpty) return 0;
    if (leftEmpty) return 1;
    if (rightEmpty) return -1;

    final leftNumber = _asNumber(left);
    final rightNumber = _asNumber(right);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }

    final leftDate = _asDate(left);
    final rightDate = _asDate(right);
    if (leftDate != null && rightDate != null) {
      return leftDate.compareTo(rightDate);
    }

    if (left is bool && right is bool) {
      return (left ? 1 : 0).compareTo(right ? 1 : 0);
    }

    return '$left'.toLowerCase().compareTo('$right'.toLowerCase());
  }

  num? _asNumber(dynamic value) {
    if (value is num) return value;
    if (value == null || value is bool) return null;
    return num.tryParse('$value');
  }

  DateTime? _asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<dynamic> _asComparableList(dynamic value) {
    if (value == null) return const <dynamic>[];
    if (value is Iterable) return value.toList(growable: false);
    if (value is Map && value['objectIds'] is Iterable) {
      return (value['objectIds'] as Iterable).toList(growable: false);
    }
    return <dynamic>[value];
  }

  List<int> _asObjectIds(dynamic value) =>
      _asComparableList(value)
          .map((item) => item is int ? item : int.tryParse('$item'))
          .whereType<int>()
          .toList(growable: false);
}
