import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppShell keeps legacy Photos navigation retired', () {
    final source = File('lib/views/app_shell.dart').readAsStringSync();

    expect(source, isNot(contains("import 'photo_management_page.dart';")));
    expect(source, isNot(contains('PhotoManagementPage(')));
    expect(
      source,
      isNot(contains("_navTile(5, Icons.photo_library_outlined, '写真')")),
    );
    expect(source, isNot(contains('(5, Icons.photo_library_outlined)')));
    expect(source, isNot(contains("('写真', Icons.photo_library_outlined, 5)")));

    // Canonical/system Object collections remain available through the
    // dynamic generic-Database navigation instead of the legacy Photo page.
    expect(source, contains('..._genericDatabases.map(_genericDatabaseTile)'));
    expect(source, contains('GenericDatabasePage('));
  });
}
