import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/database_view_tab_overflow_policy.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseViewConfig view(int id) => DatabaseViewConfig(
      id: id,
      workspaceId: 1,
      databaseKey: 'custom:books',
      name: 'View $id',
      layoutType: 'table',
      filters: const <String, dynamic>{},
      sorts: const <dynamic>[],
      visibleProperties: const <String>[],
      propertyOrder: const <String>[],
      settings: const <String, dynamic>{},
      sortOrder: id,
    );

void main() {
  test('keeps every View visible when count is within the limit', () {
    const policy = DatabaseViewTabOverflowPolicy(maxVisibleTabs: 4);
    final result = policy.partition(
      views: <DatabaseViewConfig>[view(1), view(2), view(3)],
      activeViewId: 2,
    );

    expect(result.visible.map((item) => item.id), <int>[1, 2, 3]);
    expect(result.overflow, isEmpty);
  });

  test('moves extra Views to overflow while preserving order', () {
    const policy = DatabaseViewTabOverflowPolicy(maxVisibleTabs: 3);
    final result = policy.partition(
      views: <DatabaseViewConfig>[
        view(1),
        view(2),
        view(3),
        view(4),
        view(5),
      ],
      activeViewId: 2,
    );

    expect(result.visible.map((item) => item.id), <int>[1, 2, 3]);
    expect(result.overflow.map((item) => item.id), <int>[4, 5]);
  });

  test('keeps an active overflow View directly visible', () {
    const policy = DatabaseViewTabOverflowPolicy(maxVisibleTabs: 3);
    final result = policy.partition(
      views: <DatabaseViewConfig>[
        view(1),
        view(2),
        view(3),
        view(4),
        view(5),
      ],
      activeViewId: 5,
    );

    expect(result.visible.map((item) => item.id), <int>[1, 2, 5]);
    expect(result.overflow.map((item) => item.id), <int>[3, 4]);
  });
}
