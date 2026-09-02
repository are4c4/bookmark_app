import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/object_view_projector.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

AppObject object(int id, String title, {required int score, required String status}) =>
    AppObject(
      id: id,
      objectTypeId: 1,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      values: {10: score, 11: status},
    );

DatabaseViewConfig view({
  String query = '',
  List<Map<String, dynamic>> filters = const [],
  List<Map<String, dynamic>> sorts = const [],
  Map<String, dynamic> settings = const {},
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
      settings: settings,
      sortOrder: 0,
    );

void main() {
  const projector = ObjectViewProjector();
  final objects = [
    object(1, 'Alpha', score: 2, status: 'Todo'),
    object(2, 'Beta', score: 5, status: 'Done'),
    object(3, 'Gamma', score: 4, status: 'Todo'),
  ];

  test('applies search, typed filters and sorts in order', () {
    final projection = projector.project(
      objects: objects,
      view: view(
        query: 'a',
        filters: const [
          {'propertyId': 10, 'operator': 'greaterThan', 'value': 2},
        ],
        sorts: const [
          {'propertyId': 10, 'direction': 'descending'},
        ],
      ),
    );

    expect(projection.objects.map((item) => item.title), ['Beta', 'Gamma']);
    expect(projection.queryState.searchQuery, 'a');
    expect(projection.isGrouped, false);
  });

  test('groups the filtered and sorted result from view settings', () {
    final projection = projector.project(
      objects: objects,
      view: view(
        sorts: const [
          {'propertyId': null, 'direction': 'ascending'},
        ],
        settings: const {
          'groupRule': {'propertyId': 11, 'includeEmpty': true},
        },
      ),
    );

    expect(projection.isGrouped, true);
    final todo = projection.groups.firstWhere((group) => group.label == 'Todo');
    final done = projection.groups.firstWhere((group) => group.label == 'Done');
    expect(todo.items.map((item) => item.title), ['Alpha', 'Gamma']);
    expect(done.items.map((item) => item.title), ['Beta']);
  });

  test('custom resolver lets computed values participate in filter and grouping', () {
    final projection = projector.project(
      objects: objects,
      view: view(
        filters: const [
          {'propertyId': 20, 'operator': 'greaterThanOrEqual', 'value': 8},
        ],
        settings: const {
          'groupRule': {'propertyId': 21, 'includeEmpty': true},
        },
      ),
      valueResolver: (object, propertyId) {
        if (propertyId == null) return object.title;
        if (propertyId == 20) return object.id * 4;
        if (propertyId == 21) return object.id.isEven ? 'Even' : 'Odd';
        return object.values[propertyId];
      },
    );

    expect(projection.objects.map((item) => item.id), [2, 3]);
    expect(
      projection.groups.map((group) => group.label).toSet(),
      {'Even', 'Odd'},
    );
  });

  test('search considers property values as well as title', () {
    final projection = projector.project(
      objects: objects,
      view: view(query: 'done'),
    );
    expect(projection.objects.map((item) => item.title), ['Beta']);
  });
}
