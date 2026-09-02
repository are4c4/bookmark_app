import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/generic_object_view_coordinator.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 9, 2);

AppObject object(int id, String title) => AppObject(
      id: id,
      objectTypeId: 7,
      title: title,
      createdAt: now,
      updatedAt: now,
    );

GenericRecord record(int id, String title) => GenericRecord(
      id: id,
      databaseId: 7,
      title: title,
      createdAt: now,
      updatedAt: now,
      values: const {},
    );

DatabaseViewConfig view({Map<String, dynamic> filters = const {}}) =>
    DatabaseViewConfig(
      id: 1,
      workspaceId: 1,
      databaseKey: 'custom:7',
      name: 'すべて',
      layoutType: 'table',
      filters: filters,
      sorts: const [],
      visibleProperties: const [],
      propertyOrder: const [],
      settings: const {},
      sortOrder: 0,
    );

void main() {
  const coordinator = GenericObjectViewCoordinator();

  test('keeps projected Object order when mapping back to records', () {
    final result = coordinator.project(
      objects: [object(2, 'Beta'), object(1, 'Alpha')],
      records: [record(1, 'Alpha'), record(2, 'Beta')],
      view: view(),
    );

    expect(result.records.map((item) => item.id), [2, 1]);
  });

  test('search projection removes unmatched records', () {
    final result = coordinator.project(
      objects: [object(1, 'Alpha'), object(2, 'Beta')],
      records: [record(1, 'Alpha'), record(2, 'Beta')],
      view: view(filters: const {'query': 'beta'}),
    );

    expect(result.records.map((item) => item.id), [2]);
  });

  test('ignores Object ids missing from legacy record presentation', () {
    final result = coordinator.project(
      objects: [object(1, 'Alpha'), object(99, 'Detached')],
      records: [record(1, 'Alpha')],
      view: view(),
    );

    expect(result.records.map((item) => item.id), [1]);
  });
}
