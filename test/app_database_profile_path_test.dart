import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profileDirectoryPath is authoritative for the native database file',
      () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_app_database_profile_path_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final vault = Directory('${sandbox.path}/Custom Vault');
    await vault.create(recursive: true);
    final database = AppDatabase(
      databaseName: 'name_must_not_choose_the_physical_location',
      profileDirectoryPath: vault.path,
    );

    try {
      await database.customSelect('SELECT 1').get();
    } finally {
      await database.close();
    }

    expect(File('${vault.path}/database.sqlite').existsSync(), isTrue);
  });
}
