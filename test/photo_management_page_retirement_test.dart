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
    final repository = File('lib/data/bookmark_repository.dart')
        .readAsStringSync();
    final database = File('lib/data/app_database.dart').readAsStringSync();

    expect(repository, isNot(contains('updatePhoto(')));
    expect(database, isNot(contains('updatePhoto(')));
  });

  test('legacy Photo delete API and ownership policy stay retired', () {
    final repository = File('lib/data/bookmark_repository.dart')
        .readAsStringSync();
    final database = File('lib/data/app_database.dart').readAsStringSync();
    final canonicalDeletion =
        File('lib/services/legacy_photo_image_deletion_service.dart')
            .readAsStringSync();

    expect(repository, isNot(contains('deletePhoto(')));
    expect(database, isNot(contains('deletePhoto(')));
    expect(
      File('lib/services/photo_managed_file_deletion_policy.dart').existsSync(),
      isFalse,
    );
    expect(canonicalDeletion, contains('deletePhotoCompatibilityRow('));
  });
}
