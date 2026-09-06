import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/services/profile_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late Directory supportDirectory;
  late Directory documentsDirectory;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('bookmark_profile_manager_');
    supportDirectory = Directory('${sandbox.path}/support');
    documentsDirectory = Directory('${sandbox.path}/documents');
    await supportDirectory.create(recursive: true);
    await documentsDirectory.create(recursive: true);
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  Future<void> writeRegistry({
    required String id,
    required String directoryPath,
  }) async {
    final registry = File('${supportDirectory.path}/bookmark_profiles.json');
    await registry.writeAsString(
      jsonEncode({
        'activeProfileId': id,
        'profiles': [
          {
            'id': id,
            'name': 'Test Vault',
            'databaseName': 'legacy_database_name',
            'directoryPath': directoryPath,
          },
        ],
      }),
    );
  }

  Future<ProfileManager> loadManager() => ProfileManager.load(
        applicationSupportDirectoryProvider: () async => supportDirectory,
        applicationDocumentsDirectoryProvider: () async => documentsDirectory,
      );

  test('load preserves a persisted custom Vault directory', () async {
    final vault = Directory('${sandbox.path}/custom-vault');
    await vault.create(recursive: true);
    await File('${vault.path}/database.sqlite').writeAsBytes(const []);
    await writeRegistry(id: 'custom', directoryPath: vault.path);

    final manager = await loadManager();

    expect(manager.state.activeProfile.id, 'custom');
    expect(manager.state.activeProfile.directoryPath, vault.path);
    expect(
      Directory('${documentsDirectory.path}/BookmarkApp/Profiles/custom').existsSync(),
      isFalse,
    );

    final savedRegistry = jsonDecode(
      await File('${supportDirectory.path}/bookmark_profiles.json').readAsString(),
    ) as Map<String, dynamic>;
    final savedProfile = (savedRegistry['profiles'] as List<dynamic>).single
        as Map<String, dynamic>;
    expect(savedProfile['directoryPath'], vault.path);
  });

  test('load falls back to the app-managed path for an empty legacy path', () async {
    await writeRegistry(id: 'legacy', directoryPath: '');

    final manager = await loadManager();

    final expected = '${documentsDirectory.path}/BookmarkApp/Profiles/legacy';
    expect(manager.state.activeProfile.directoryPath, expected);
    expect(Directory(expected).existsSync(), isTrue);
    expect(Directory('$expected/photos').existsSync(), isTrue);
  });

  test('load does not recreate a missing persisted custom Vault', () async {
    final missingVault = Directory('${sandbox.path}/missing-vault');
    await writeRegistry(id: 'missing', directoryPath: missingVault.path);

    await expectLater(
      loadManager(),
      throwsA(isA<FileSystemException>()),
    );
    expect(missingVault.existsSync(), isFalse);
  });

  test('load fails closed when a persisted custom Vault has no database', () async {
    final incompleteVault = Directory('${sandbox.path}/incomplete-vault');
    await incompleteVault.create(recursive: true);
    await writeRegistry(id: 'incomplete', directoryPath: incompleteVault.path);

    await expectLater(
      loadManager(),
      throwsA(isA<FileSystemException>()),
    );
    expect(File('${incompleteVault.path}/database.sqlite').existsSync(), isFalse);
  });
}
