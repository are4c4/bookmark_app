import 'dart:io';

import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_availability_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = VaultAvailabilityService();

  test('reports a missing Vault directory without creating it', () async {
    final sandbox = await Directory.systemTemp.createTemp('vault_availability_');
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });
    final missing = Directory('${sandbox.path}/missing');
    final profile = DatabaseProfile(
      id: 'missing',
      name: 'Missing',
      databaseName: 'missing-db',
      directoryPath: missing.path,
    );

    expect(await service.check(profile), VaultAvailability.missingDirectory);
    expect(missing.existsSync(), isFalse);
  });

  test('distinguishes an existing directory with a missing database', () async {
    final sandbox = await Directory.systemTemp.createTemp('vault_availability_');
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });
    final vault = Directory('${sandbox.path}/vault');
    await vault.create(recursive: true);
    final marker = File('${vault.path}/keep.txt');
    await marker.writeAsString('keep');
    final profile = DatabaseProfile(
      id: 'missing-db',
      name: 'Missing DB',
      databaseName: 'missing-db',
      directoryPath: vault.path,
    );

    expect(await service.check(profile), VaultAvailability.missingDatabase);
    expect(await marker.readAsString(), 'keep');
  });

  test('reports an existing database as available', () async {
    final sandbox = await Directory.systemTemp.createTemp('vault_availability_');
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });
    final vault = Directory('${sandbox.path}/vault');
    await vault.create(recursive: true);
    await File('${vault.path}/database.sqlite').writeAsBytes(const []);
    final profile = DatabaseProfile(
      id: 'available',
      name: 'Available',
      databaseName: 'available-db',
      directoryPath: vault.path,
    );

    expect(await service.check(profile), VaultAvailability.available);
  });
}
