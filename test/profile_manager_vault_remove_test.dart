import 'dart:io';

import 'package:bookmark_app/services/profile_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late Directory supportDirectory;
  late Directory documentsDirectory;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('bookmark_vault_remove_');
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

  Future<ProfileManager> loadManager() => ProfileManager.load(
        applicationSupportDirectoryProvider: () async => supportDirectory,
        applicationDocumentsDirectoryProvider: () async => documentsDirectory,
      );

  test('shell-compatible Vault removal preserves app-managed files', () async {
    final manager = await loadManager();
    final profile = await manager.createProfile('Managed Vault');
    final marker = File('${profile.directoryPath}/keep.txt');
    await marker.writeAsString('keep this Vault');

    await manager.deleteProfile(profile);

    expect(
      manager.state.profiles.any((candidate) => candidate.id == profile.id),
      isFalse,
    );
    expect(Directory(profile.directoryPath).existsSync(), isTrue);
    expect(await marker.readAsString(), 'keep this Vault');

    final reloaded = await loadManager();
    expect(
      reloaded.state.profiles.any((candidate) => candidate.id == profile.id),
      isFalse,
    );
    expect(Directory(profile.directoryPath).existsSync(), isTrue);
  });

  test('explicit removeProfile also preserves app-managed files', () async {
    final manager = await loadManager();
    final profile = await manager.createProfile('Removable Vault');
    final marker = File('${profile.directoryPath}/keep.txt');
    await marker.writeAsString('still here');

    await manager.removeProfile(profile);

    expect(
      manager.state.profiles.any((candidate) => candidate.id == profile.id),
      isFalse,
    );
    expect(Directory(profile.directoryPath).existsSync(), isTrue);
    expect(await marker.readAsString(), 'still here');
  });
}
