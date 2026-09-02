import 'package:bookmark_app/data/database_view_group_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseViewConfig view({Map<String, dynamic> settings = const {}}) =>
    DatabaseViewConfig(
      id: 1,
      workspaceId: 1,
      databaseKey: 'custom:1',
      name: 'Board',
      layoutType: 'board',
      filters: const {},
      sorts: const [],
      visibleProperties: const [],
      propertyOrder: const [],
      settings: settings,
      sortOrder: 0,
    );

void main() {
  const adapter = DatabaseViewGroupAdapter();

  test('encodes and decodes group rule while preserving other settings', () {
    final encoded = adapter.encode(
      view(settings: const {'cardSize': 'medium'}),
      group: const ObjectGroupRule(propertyId: 12, includeEmpty: false),
    );
    final group = adapter.decode(encoded);

    expect(group?.propertyId, 12);
    expect(group?.includeEmpty, false);
    expect(encoded.settings['cardSize'], 'medium');
  });

  test('clear removes only group setting', () {
    final encoded = adapter.encode(
      view(settings: const {'preview': 'cover'}),
      group: const ObjectGroupRule(propertyId: 7),
    );
    final cleared = adapter.clear(encoded);

    expect(adapter.decode(cleared), isNull);
    expect(cleared.settings['preview'], 'cover');
  });

  test('malformed group setting is ignored', () {
    expect(
      adapter.decode(view(settings: const {'groupRule': 'broken'})),
      isNull,
    );
  });
}
