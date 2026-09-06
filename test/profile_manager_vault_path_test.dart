import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/services/profile_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late Directory supportDirectory;
  late Directory documentsDirectory;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('bookmark_profile_manager_');
    supportDirectory = Directory('${sandbox.path}/support');
    documentsDirectory = Directory('${sandbox.path}/documents');
    await supportDirectory.create(recursive: true);
    await documentsDirectory.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getTemporaryDirectory') return sandbox.path;
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
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

  Future<void> writeVaultMetadata(
    Directory vault, {
    required String id,
    required String name,
  }) =>
      File('${vault.path}/profile.json').writeAsString(
        jsonEncode({
          'formatVersion': 1,
          'id': id,
          'name': name,
          'database': 'database.sqlite',
          'photos': 'photos',
          'attachments': 'attachments',
        }),
      );

  Future<void> initializeVaultDatabase(Directory vault) async {
    final database = AppDatabase(
      databaseName: 'vault_test_database',
      profileDirectoryPath: vault.path,
    );
    try {
      await database.customSelect('SELECT 1').get();
    } finally {
      await database.close();
    }
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

  test('createVault initializes a portable Vault before registering it', () async {
    final manager = await loadManager();
    final vault = Directory('${sandbox.path}/Created Vault');

    final profile = await manager.createVault(
      name: 'Created Vault',
      directoryPath: vault.path,
    );

    expect(profile.directoryPath, vault.path);
    expect(File('${vault.path}/database.sqlite').existsSync(), isTrue);
    expect(File('${vault.path}/profile.json').existsSync(), isTrue);
    expect(Directory('${vault.path}/photos').existsSync(), isTrue);
    expect(Directory('${vault.path}/attachments').existsSync(), isTrue);
    expect(
      manager.state.profiles.any((candidate) => candidate.id == profile.id),
      isTrue,
    );
    expect(manager.state.activeProfileId, 'default');

    final metadata = jsonDecode(
      await File('${vault.path}/profile.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(metadata['database'], 'database.sqlite');
    expect(metadata.containsKey('directoryPath'), isFalse);
  });

  test('createVault refuses a non-empty directory without overwriting it', () async {
    final manager = await loadManager();
    final vault = Directory('${sandbox.path}/Existing Folder');
    await vault.create(recursive: true);
    final marker = File('${vault.path}/keep.txt');
    await marker.writeAsString('keep me');

    await expectLater(
      manager.createVault(name: 'Unsafe', directoryPath: vault.path),
      throwsA(isA<FileSystemException>()),
    );

    expect(await marker.readAsString(), 'keep me');
    expect(File('${vault.path}/database.sqlite').existsSync(), isFalse);
    expect(File('${vault.path}/profile.json').existsSync(), isFalse);
    expect(manager.state.profiles.length, 1);
  });

  test('openVault validates and registers an existing Vault in place', () async {
    final manager = await loadManager();
    final vault = Directory('${sandbox.path}/Existing Vault');
    await vault.create(recursive: true);
    await initializeVaultDatabase(vault);
    await writeVaultMetadata(vault, id: 'portable-vault', name: 'Portable Vault');

    final profile = await manager.openVault(vault.path);

    expect(profile.id, 'portable-vault');
    expect(profile.name, 'Portable Vault');
    expect(profile.directoryPath, vault.path);
    expect(manager.state.profiles.length, 2);
    expect(
      Directory('${documentsDirectory.path}/BookmarkApp/Profiles/portable-vault')
          .existsSync(),
      isFalse,
    );
    expect(File('${vault.path}/database.sqlite').existsSync(), isTrue);
  });

  test('openVault does not create a database for an invalid Vault', () async {
    final manager = await loadManager();
    final vault = Directory('${sandbox.path}/Invalid Vault');
    await vault.create(recursive: true);
    await writeVaultMetadata(vault, id: 'invalid-vault', name: 'Invalid Vault');

    await expectLater(
      manager.openVault(vault.path),
      throwsA(isA<FileSystemException>()),
    );

    expect(File('${vault.path}/database.sqlite').existsSync(), isFalse);
    expect(manager.state.profiles.length, 1);
  });

  test('deleting a custom Vault profile unregisters without deleting files', () async {
    final manager = await loadManager();
    final vault = Directory('${sandbox.path}/Keep Vault');
    await vault.create(recursive: true);
    await initializeVaultDatabase(vault);
    await writeVaultMetadata(vault, id: 'keep-vault', name: 'Keep Vault');
    final marker = File('${vault.path}/keep.txt');
    await marker.writeAsString('user data');

    final profile = await manager.openVault(vault.path);
    await manager.deleteProfile(profile);

    expect(vault.existsSync(), isTrue);
    expect(await marker.readAsString(), 'user data');
    expect(
      manager.state.profiles.any((candidate) => candidate.id == profile.id),
      isFalse,
    );
  });
}
