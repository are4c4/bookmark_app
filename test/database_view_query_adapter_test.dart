import 'package:bookmark_app/data/database_view_query_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseViewConfig view({
  Map<String, dynamic> filters = const <String, dynamic>{},
  List<dynamic> sorts = const <dynamic>[],
}) =>
    DatabaseViewConfig(
      id: 1,
      workspaceId: 1,
      databaseKey: 'custom:1',
      name: 'すべて',
      layoutType: 'table',
      filters: filters,
      sorts: sorts,
      visibleProperties: const [],
      propertyOrder: const [],
      settings: const {},
      sortOrder: 0,
    );

void main() {
  const adapter = DatabaseViewQueryAdapter();

  test('encodes and decodes property filters and sorts', () {
    final encoded = adapter.encode(
      view(filters: const {'query': 'math', 'legacy': true}),
      filters: const [
        ObjectFilterRule(
          propertyId: 12,
          operator: ObjectFilterOperator.greaterThan,
          value: 3,
        ),
      ],
      sorts: const [
        ObjectSortRule(
          propertyId: null,
          direction: ObjectSortDirection.descending,
        ),
      ],
    );

    final decoded = adapter.decode(encoded);
    expect(decoded.searchQuery, 'math');
    expect(decoded.filters, hasLength(1));
    expect(decoded.filters.single.propertyId, 12);
    expect(decoded.filters.single.operator, ObjectFilterOperator.greaterThan);
    expect(decoded.sorts, hasLength(1));
    expect(decoded.sorts.single.direction, ObjectSortDirection.descending);
    expect(encoded.filters['legacy'], true);
  });

  test('malformed stored query rules are ignored safely', () {
    final decoded = adapter.decode(
      view(
        filters: const {
          'query': 'x',
          'propertyRules': [
            {'operator': 'unknown', 'propertyId': 1},
            'broken',
          ],
        },
        sorts: const [
          {'direction': 'unknown'},
          123,
        ],
      ),
    );

    expect(decoded.searchQuery, 'x');
    expect(decoded.filters, isEmpty);
    expect(decoded.sorts, isEmpty);
  });

  test('clear operations preserve search query and unrelated filter settings', () {
    final original = adapter.encode(
      view(filters: const {'query': 'keep', 'favoritesOnly': true}),
      filters: const [
        ObjectFilterRule(
          propertyId: 1,
          operator: ObjectFilterOperator.equals,
          value: 'A',
        ),
      ],
      sorts: const [
        ObjectSortRule(
          propertyId: 2,
          direction: ObjectSortDirection.ascending,
        ),
      ],
    );

    final clearedFilters = adapter.clearFilters(original);
    final clearedSorts = adapter.clearSorts(clearedFilters);
    final decoded = adapter.decode(clearedSorts);
    expect(decoded.searchQuery, 'keep');
    expect(decoded.filters, isEmpty);
    expect(decoded.sorts, isEmpty);
    expect(clearedSorts.filters['favoritesOnly'], true);
  });
}
