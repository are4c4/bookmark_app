import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Photo management page stays retired from production', () {
    expect(File('lib/views/photo_management_page.dart').existsSync(), isFalse);

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('PhotoManagementPage')),
        reason: 'Legacy Photo management host returned in ${file.path}',
      );
      expect(
        source,
        isNot(contains('photo_management_page.dart')),
        reason: 'Legacy Photo management import returned in ${file.path}',
      );
    }
  });

  test('legacy Photo metadata update APIs stay retired', () {
    final repository =
        File('lib/data/bookmark_repository.dart').readAsStringSync();
    final database = File('lib/data/app_database.dart').readAsStringSync();

    expect(repository, isNot(contains('updatePhoto(')));
    expect(database, isNot(contains('updatePhoto(')));
  });
}
