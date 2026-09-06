import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/services/vault_availability_service.dart';
import 'package:bookmark_app/services/vault_registry_inspection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late Directory support;
  late Directory documents;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('vault_registry_inspection_');
    support = Directory('${sandbox.path}/support');
    documents = Directory('${sandbox.path}/documents');
    await support.create(recursive: true);
    await documents.create(recursive: true);
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  VaultRegistryInspectionService service() => VaultRegistryInspectionService(
        applicationSupportDirectoryProvider: () async => support,
        applicationDocumentsDirectoryProvider: () async => documents,
      );

  Future<void> writeRegistry(Map<String, Object?> value) => File(
        '${support.path}/bookmark_profiles.json',
      ).writeAsString(jsonEncode(value));

  test('classifies registered Vault locations without mutating them', () async {
    final available = Directory('${sandbox.path}/Available Vault');
    await available.create(recursive: true);
    await File('${available.path}/database.sqlite').writeAsBytes([1, 2, 3]);
    final missing = '${sandbox.path}/Missing Vault';
    await writeRegistry({
      'activeProfileId': 'missing',
      'profiles': [
        {
          'id': 'available',
          'name': 'Available',
          'databaseName': 'custom-db-name',
          'directoryPath': available.path,
        },
        {
          'id': 'missing',
          'name': 'Missing',
          'databaseName': 'missing-db',
          'directoryPath': missing,
        },
      ],
    });

    final locations = await service().inspect();

    expect(locations, hasLength(2));
    expect(locations[0].profile.directoryPath, available.path);
    expect(locations[0].profile.databaseName, 'custom-db-name');
    expect(locations[0].availability, VaultAvailability.available);
    expect(locations[0].isActive, isFalse);
    expect(locations[1].profile.directoryPath, missing);
    expect(locations[1].availability, VaultAvailability.missingDirectory);
    expect(locations[1].isActive, isTrue);
    expect(Directory(missing).existsSync(), isFalse);
  });

  test('resolves legacy empty directoryPath to the managed Documents location',
      () async {
    final managed = Directory('${documents.path}/BookmarkApp/Profiles/legacy');
    await managed.create(recursive: true);
    await File('${managed.path}/database.sqlite').writeAsBytes([1]);
    await writeRegistry({
      'activeProfileId': 'legacy',
      'profiles': [
        {
          'id': 'legacy',
          'name': 'Legacy',
          'databaseName': '',
          'directoryPath': '',
        },
      ],
    });

    final location = (await service().inspect()).single;

    expect(location.profile.directoryPath, managed.path);
    expect(
      location.profile.databaseName,
      'BookmarkApp/Profiles/legacy/database',
    );
    expect(location.availability, VaultAvailability.available);
    expect(location.isActive, isTrue);
  });

  test('distinguishes an existing Vault folder whose database is missing',
      () async {
    final directory = Directory('${sandbox.path}/No Database');
    await directory.create(recursive: true);
    await writeRegistry({
      'activeProfileId': 'no-db',
      'profiles': [
        {
          'id': 'no-db',
          'name': 'No DB',
          'directoryPath': directory.path,
        },
      ],
    });

    final location = (await service().inspect()).single;

    expect(location.availability, VaultAvailability.missingDatabase);
    expect(await directory.list().isEmpty, isTrue);
  });

  test('missing registry returns no recovery candidates and creates nothing',
      () async {
    expect(await service().inspect(), isEmpty);
    expect(
      File('${support.path}/bookmark_profiles.json').existsSync(),
      isFalse,
    );
    expect(Directory('${documents.path}/BookmarkApp').existsSync(), isFalse);
  });

  test('malformed registry fails closed without filesystem mutation', () async {
    final registry = File('${support.path}/bookmark_profiles.json');
    await registry.writeAsString('{broken');
    final before = await registry.readAsString();

    await expectLater(service().inspect(), throwsFormatException);

    expect(await registry.readAsString(), before);
    expect(Directory('${documents.path}/BookmarkApp').existsSync(), isFalse);
  });
}
