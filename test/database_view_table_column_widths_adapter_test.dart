import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/database_view_table_column_widths_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseViewConfig _view({Map<String, dynamic> settings = const {}}) =>
    DatabaseViewConfig(
      id: 7,
      workspaceId: 1,
      databaseKey: 'custom:4',
      name: 'Table',
      layoutType: 'table',
      filters: const {},
      sorts: const [],
      visibleProperties: const ['p:11', 'p:22'],
      propertyOrder: const ['p:11', 'p:22'],
      settings: settings,
      sortOrder: 0,
    );

void main() {
  const adapter = DatabaseViewTableColumnWidthsAdapter();

  test(
    'stores widths by stable column key and preserves unrelated settings',
    () {
      final original = _view(
        settings: const <String, dynamic>{
          'galleryMode': 'fit',
          DatabaseViewTableColumnWidthsAdapter.settingsKey: <String, dynamic>{
            'p:11': 220,
            'removed:p:99': 330,
          },
        },
      );

      final next = adapter.withWidth(original, key: 'p:22', width: 280);

      expect(next.settings['galleryMode'], 'fit');
      expect(adapter.decode(next), <String, dynamic>{
        'p:11': 220,
        'removed:p:99': 330,
        'p:22': 280.0,
      });
      expect(next.propertyOrder, original.propertyOrder);
      expect(next.visibleProperties, original.visibleProperties);
    },
  );

  test('malformed metadata fails soft without changing the View', () {
    final original = _view(
      settings: const <String, dynamic>{
        DatabaseViewTableColumnWidthsAdapter.settingsKey: 'old-format',
        'other': true,
      },
    );

    expect(adapter.decode(original), isEmpty);

    final next = adapter.withWidth(original, key: 'title', width: 240);
    expect(next.settings['other'], isTrue);
    expect(adapter.decode(next), <String, dynamic>{'title': 240.0});
  });
}
