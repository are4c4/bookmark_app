import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/services/vault_registry_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _writeCandidate(
  Directory directory, {
  required String id,
}) async {
  await directory.create(recursive: true);
  await File('${directory.path}/profile.json').writeAsString(
    jsonEncode({
      'formatVersion': 1,
      'id': id,
      'name': 'Portable Vault',
      'database': 'database.sqlite',
      'photos': 'photos',
      'attachments': 'attachments',
    }),
  );
  await File('${directory.path}/database.sqlite').writeAsBytes([
    ...'SQLite format 3\u0000'.codeUnits,
    0,
    1,
    2,
    3,
  ]);
}

void main() {
  late Directory sandbox;
  late Directory support;
  late File registry;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('vault_registry_recovery_');
    support = Directory('${sandbox.path}/support');
    await support.create(recursive: true);
    registry = File('${support.path}/bookmark_profiles.json');
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  Future<void> writeRegistry({
    String targetPath = '/missing/old-vault',
    String otherPath = '/available/other-vault',
  }) =>
      registry.writeAsString(
        jsonEncode({
          'activeProfileId': 'target',
          'futureRootField': {'keep': true},
          'profiles': [
            {
              'id': 'target',
              'name': 'Target Vault',
              'databaseName': 'BookmarkApp/Profiles/target/database',
              'directoryPath': targetPath,
              'futureProfileField': 42,
            },
            {
              'id': 'other',
              'name': 'Other Vault',
              'databaseName': 'BookmarkApp/Profiles/other/database',
              'directoryPath': otherPath,
              'otherFutureField': 'keep-me',
            },
          ],
        }),
      );

  VaultRegistryRecoveryService service() => VaultRegistryRecoveryService(
        applicationSupportDirectoryProvider: () async => support,
      );

  test('relink changes only the matching directory path and preserves registry data',
      () async {
    await writeRegistry();
    final candidate = Directory('${sandbox.path}/Moved Vault');
    await _writeCandidate(candidate, id: 'target');

    final repaired = await service().relink(
      profileId: 'target',
      directoryPath: candidate.path,
    );

    expect(repaired.id, 'target');
    expect(repaired.name, 'Target Vault');
    expect(repaired.directoryPath, candidate.path);

    final decoded = jsonDecode(await registry.readAsString()) as Map<String, dynamic>;
    expect(decoded['activeProfileId'], 'target');
    expect(decoded['futureRootField'], {'keep': true});
    final profiles = (decoded['profiles'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final target = profiles.firstWhere((profile) => profile['id'] == 'target');
    final other = profiles.firstWhere((profile) => profile['id'] == 'other');
    expect(target['directoryPath'], candidate.path);
    expect(target['futureProfileField'], 42);
    expect(other['directoryPath'], '/available/other-vault');
    expect(
      support.listSync().whereType<File>().map((file) => file.path),
      everyElement(isNot(contains('.relink-'))),
    );
  });

  test('wrong Vault id fails before changing the registry', () async {
    await writeRegistry();
    final original = await registry.readAsString();
    final candidate = Directory('${sandbox.path}/Wrong Vault');
    await _writeCandidate(candidate, id: 'different');

    await expectLater(
      service().relink(profileId: 'target', directoryPath: candidate.path),
      throwsA(isA<FormatException>()),
    );

    expect(await registry.readAsString(), original);
  });

  test('unknown registered id fails without changing the registry', () async {
    await writeRegistry();
    final original = await registry.readAsString();
    final candidate = Directory('${sandbox.path}/Unknown');
    await _writeCandidate(candidate, id: 'unknown');

    await expectLater(
      service().relink(profileId: 'unknown', directoryPath: candidate.path),
      throwsA(isA<StateError>()),
    );

    expect(await registry.readAsString(), original);
  });

  test('a folder already registered to another Vault is rejected', () async {
    final candidate = Directory('${sandbox.path}/Shared');
    await _writeCandidate(candidate, id: 'target');
    await writeRegistry(otherPath: candidate.path);
    final original = await registry.readAsString();

    await expectLater(
      service().relink(profileId: 'target', directoryPath: candidate.path),
      throwsA(isA<StateError>()),
    );

    expect(await registry.readAsString(), original);
  });

  test('missing registry fails without creating one', () async {
    final candidate = Directory('${sandbox.path}/Candidate');
    await _writeCandidate(candidate, id: 'target');

    await expectLater(
      service().relink(profileId: 'target', directoryPath: candidate.path),
      throwsA(isA<FileSystemException>()),
    );

    expect(registry.existsSync(), isFalse);
  });

  test('unregisterInactive removes only registry metadata and keeps Vault files',
      () async {
    final otherDirectory = Directory('${sandbox.path}/Other Vault');
    await otherDirectory.create(recursive: true);
    final marker = File('${otherDirectory.path}/keep.txt');
    await marker.writeAsString('user data');
    await writeRegistry(otherPath: otherDirectory.path);

    await service().unregisterInactive('other');

    final decoded = jsonDecode(await registry.readAsString()) as Map<String, dynamic>;
    expect(decoded['activeProfileId'], 'target');
    expect(decoded['futureRootField'], {'keep': true});
    final profiles = (decoded['profiles'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(profiles, hasLength(1));
    expect(profiles.single['id'], 'target');
    expect(profiles.single['futureProfileField'], 42);
    expect(await marker.readAsString(), 'user data');
    expect(otherDirectory.existsSync(), isTrue);
  });

  test('unregisterInactive refuses the active Vault without registry mutation',
      () async {
    await writeRegistry();
    final original = await registry.readAsString();

    await expectLater(
      service().unregisterInactive('target'),
      throwsA(isA<StateError>()),
    );

    expect(await registry.readAsString(), original);
  });

  test('unregisterInactive refuses the last remaining Vault', () async {
    await registry.writeAsString(
      jsonEncode({
        'activeProfileId': 'only',
        'profiles': [
          {
            'id': 'only',
            'name': 'Only Vault',
            'directoryPath': '/missing/only',
          },
        ],
      }),
    );
    final original = await registry.readAsString();

    await expectLater(
      service().unregisterInactive('only'),
      throwsA(isA<StateError>()),
    );

    expect(await registry.readAsString(), original);
  });

  test('unregisterInactive rejects unknown ids without registry mutation',
      () async {
    await writeRegistry();
    final original = await registry.readAsString();

    await expectLater(
      service().unregisterInactive('unknown'),
      throwsA(isA<StateError>()),
    );

    expect(await registry.readAsString(), original);
  });
}
