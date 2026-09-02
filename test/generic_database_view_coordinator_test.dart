import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/generic_database_view_coordinator.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

AppObject object(int id, String title, {required int score}) => AppObject(
      id: id,
      objectTypeId: 1,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      values: {10: score},
    );

GenericRecord record(int id, String title, {required int score}) => GenericRecord(
      id: id,
      databaseId: 1,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      values: {10: score},
    );

DatabaseViewConfig view({
  String query = '',
  List<Map<String, dynamic>> filters = const [],
  List<Map<String, dynamic>> sorts = const [],
}) =>
    DatabaseViewConfig(
      id: 1,
      workspaceId: 1,
      databaseKey: 'custom:1',
      name: 'すべて',
      layoutType: 'table',
      filters: {'query': query, 'propertyRules': filters},
      sorts: sorts,
      visibleProperties: const [],
      propertyOrder: const [],
      settings: const {},
      sortOrder: 0,
    );

void main() {
  const coordinator = GenericDatabaseViewCoordinator();

  test('returns GenericRecords in the shared Object projection order', () {
    final objects = [
      object(1, 'Alpha', score: 2),
      object(2, 'Beta', score: 5),
      object(3, 'Gamma', score: 4),
    ];
    final records = [
      record(1, 'Alpha', score: 2),
      record(2, 'Beta', score: 5),
      record(3, 'Gamma', score: 4),
    ];

    final result = coordinator.project(
      objects: objects,
      records: records,
      view: view(
        filters: const [
          {'propertyId': 10, 'operator': 'greaterThan', 'value': 2},
        ],
        sorts: const [
          {'propertyId': 10, 'direction': 'descending'},
        ],
      ),
    );

    expect(result.objectProjection.objects.map((item) => item.id), [2, 3]);
    expect(result.records.map((item) => item.id), [2, 3]);
  });

  test('computed values participate in projection without mutating records', () {
    final objects = [
      object(1, 'Alpha', score: 2),
      object(2, 'Beta', score: 5),
    ];
    final records = [
      record(1, 'Alpha', score: 2),
      record(2, 'Beta', score: 5),
    ];

    final result = coordinator.project(
      objects: objects,
      records: records,
      view: view(
        filters: const [
          {'propertyId': 20, 'operator': 'greaterThan', 'value': 5},
        ],
      ),
      computedValues: const {
        1: {20: 4},
        2: {20: 10},
      },
    );

    expect(result.records.map((item) => item.id), [2]);
    expect(records[1].values.containsKey(20), false);
  });

  test('withSearch preserves typed filter and sort configuration', () {
    final original = view(
      filters: const [
        {'propertyId': 10, 'operator': 'greaterThan', 'value': 1},
      ],
      sorts: const [
        {'propertyId': 10, 'direction': 'ascending'},
      ],
    );

    final next = coordinator.withSearch(original, 'beta');

    expect(next.filters['query'], 'beta');
    expect(next.filters['propertyRules'], original.filters['propertyRules']);
    expect(next.sorts, original.sorts);
  });

  test('persist returns the saved view after saver completes', () async {
    final next = view(query: 'saved');
    DatabaseViewConfig? saved;

    final result = await coordinator.persist(next, (value) async {
      saved = value;
    });

    expect(identical(result, next), true);
    expect(saved?.filters['query'], 'saved');
  });
}
