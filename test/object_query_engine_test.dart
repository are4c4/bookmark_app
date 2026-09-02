import 'package:bookmark_app/data/object_query_engine.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:flutter_test/flutter_test.dart';

AppObject object(
  int id,
  String title, {
  Map<int, dynamic> values = const <int, dynamic>{},
}) =>
    AppObject(
      id: id,
      objectTypeId: 1,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      values: values,
    );

void main() {
  const engine = ObjectQueryEngine();

  test('filters title and numeric property values', () {
    final objects = [
      object(1, 'Alpha', values: {10: 5}),
      object(2, 'Beta', values: {10: 12}),
      object(3, 'Alphabet', values: {10: 20}),
    ];
    final result = engine.apply(
      objects: objects,
      filters: const [
        ObjectFilterRule(propertyId: null, operator: ObjectFilterOperator.contains, value: 'alpha'),
        ObjectFilterRule(propertyId: 10, operator: ObjectFilterOperator.greaterThan, value: 10),
      ],
    );
    expect(result.map((item) => item.id), [3]);
  });

  test('containsAny and containsAll work for multiselect and relation ids', () {
    final objects = [
      object(1, 'A', values: {10: ['math', 'book'], 11: [5, 6]}),
      object(2, 'B', values: {10: ['photo'], 11: [7]}),
    ];
    expect(
      engine.apply(objects: objects, filters: const [
        ObjectFilterRule(propertyId: 10, operator: ObjectFilterOperator.containsAll, value: ['book', 'math']),
      ]).map((item) => item.id),
      [1],
    );
    expect(
      engine.apply(objects: objects, filters: const [
        ObjectFilterRule(propertyId: 11, operator: ObjectFilterOperator.containsAny, value: [6, 9]),
      ]).map((item) => item.id),
      [1],
    );
  });

  test('before and after parse ISO dates', () {
    final objects = [
      object(1, 'Old', values: {10: '2026-01-01'}),
      object(2, 'New', values: {10: '2026-09-01'}),
    ];
    final result = engine.apply(objects: objects, filters: const [
      ObjectFilterRule(propertyId: 10, operator: ObjectFilterOperator.after, value: '2026-06-01'),
    ]);
    expect(result.map((item) => item.id), [2]);
  });

  test('applies multiple stable sort rules with empty values last', () {
    final objects = [
      object(1, 'B', values: {10: 2}),
      object(2, 'A', values: {10: 2}),
      object(3, 'C', values: {10: 1}),
      object(4, 'Empty'),
    ];
    final result = engine.apply(objects: objects, sorts: const [
      ObjectSortRule(propertyId: 10, direction: ObjectSortDirection.ascending),
      ObjectSortRule(propertyId: null, direction: ObjectSortDirection.ascending),
    ]);
    expect(result.map((item) => item.id), [3, 2, 1, 4]);
  });

  test('custom value resolver supports computed properties', () {
    final objects = [object(1, 'A'), object(2, 'B')];
    final computed = <int, num>{1: 20, 2: 5};
    final result = engine.apply(
      objects: objects,
      filters: const [
        ObjectFilterRule(propertyId: 99, operator: ObjectFilterOperator.greaterThanOrEqual, value: 10),
      ],
      valueResolver: (item, propertyId) => propertyId == null ? item.title : computed[item.id],
    );
    expect(result.map((item) => item.id), [1]);
  });

  test('query rules round-trip through JSON maps', () {
    const filter = ObjectFilterRule(propertyId: 12, operator: ObjectFilterOperator.contains, value: 'abc');
    const sort = ObjectSortRule(propertyId: null, direction: ObjectSortDirection.descending);
    final decodedFilter = ObjectFilterRule.fromJson(filter.toJson());
    final decodedSort = ObjectSortRule.fromJson(sort.toJson());
    expect(decodedFilter?.propertyId, 12);
    expect(decodedFilter?.operator, ObjectFilterOperator.contains);
    expect(decodedFilter?.value, 'abc');
    expect(decodedSort?.propertyId, isNull);
    expect(decodedSort?.direction, ObjectSortDirection.descending);
  });
}
