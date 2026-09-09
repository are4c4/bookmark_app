import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/services/profile_backup_service.dart';
import 'package:bookmark_app/services/vault_backup_destination_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const guard = VaultBackupDestinationGuard();

  test('rejects direct and nested destinations inside the source Vault', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_vault_backup_destination_inside_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    final vault = Directory('${sandbox.path}/vault');
    await Directory('${vault.path}/photos').create(recursive: true);
    await Directory('${vault.path}/attachments').create(recursive: true);

    for (final destination in <String>[
      '${vault.path}/backup.zip',
      '${vault.path}/photos/backup.zip',
      '${vault.path}/attachments/nested/backup.zip',
    ]) {
      if (destination.contains('/nested/')) {
        await Directory('${vault.path}/attachments/nested').create();
      }
      await expectLater(
        guard.validate(
          sourceVaultPath: vault.path,
          destinationPath: destination,
        ),
        throwsA(isA<FileSystemException>()),
        reason: destination,
      );
      expect(File(destination).existsSync(), isFalse, reason: destination);
    }
  });

  test('allows an ordinary sibling destination outside the source Vault', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_vault_backup_destination_outside_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    final vault = Directory('${sandbox.path}/vault');
    await vault.create();

    await guard.validate(
      sourceVaultPath: vault.path,
      destinationPath: '${sandbox.path}/backup.zip',
    );
  });

  test('rejects a destination whose parent symlink resolves into the Vault', () async {
    if (Platform.isWindows) return;

    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_vault_backup_destination_parent_link_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    final vault = Directory('${sandbox.path}/vault');
    await vault.create();
    final alias = Link('${sandbox.path}/vault-alias');
    await alias.create(vault.path);

    await expectLater(
      guard.validate(
        sourceVaultPath: vault.path,
        destinationPath: '${alias.path}/backup.zip',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(File('${vault.path}/backup.zip').existsSync(), isFalse);
  });

  test('rejects an existing destination symlink targeting the Vault', () async {
    if (Platform.isWindows) return;

    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_vault_backup_destination_file_link_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    final vault = Directory('${sandbox.path}/vault');
    await vault.create();
    final target = File('${vault.path}/existing.zip');
    await target.writeAsBytes([1, 2, 3]);
    final destination = Link('${sandbox.path}/backup.zip');
    await destination.create(target.path);

    await expectLater(
      guard.validate(
        sourceVaultPath: vault.path,
        destinationPath: destination.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.readAsBytes(), [1, 2, 3]);
  });

  test('export rejects a Vault-local destination before checkpoint/output', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_backup_inside_guard_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    final vault = Directory('${sandbox.path}/vault');
    await vault.create();
    final sentinel = File('${vault.path}/keep.txt');
    await sentinel.writeAsString('keep');
    final database = AppDatabase(profileDirectoryPath: vault.path);
    addTearDown(database.close);
    final destination = '${vault.path}/backup.zip';

    await expectLater(
      ProfileBackupService(
        exportDestinationPicker: (_) async => destination,
      ).exportProfile(
        profileName: 'Vault',
        profileDirectoryPath: vault.path,
        database: database,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(File(destination).existsSync(), isFalse);
    expect(File('${vault.path}/database.sqlite').existsSync(), isFalse);
    expect(await sentinel.readAsString(), 'keep');
  });

  test('export cancellation returns null without checkpointing the Vault', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_backup_cancel_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    final vault = Directory('${sandbox.path}/vault');
    await vault.create();
    final database = AppDatabase(profileDirectoryPath: vault.path);
    addTearDown(database.close);

    final result = await ProfileBackupService(
      exportDestinationPicker: (_) async => null,
    ).exportProfile(
      profileName: 'Vault',
      profileDirectoryPath: vault.path,
      database: database,
    );

    expect(result, isNull);
    expect(File('${vault.path}/database.sqlite').existsSync(), isFalse);
  });

  test('export still writes a complete backup to an outside destination', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_backup_outside_guard_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    final vault = Directory('${sandbox.path}/vault');
    await vault.create();
    await File('${vault.path}/profile.json').writeAsString('{}');
    final database = AppDatabase(profileDirectoryPath: vault.path);
    addTearDown(database.close);
    final destination = '${sandbox.path}/backup.zip';

    final result = await ProfileBackupService(
      exportDestinationPicker: (_) async => destination,
    ).exportProfile(
      profileName: 'Vault',
      profileDirectoryPath: vault.path,
      database: database,
    );

    expect(result, destination);
    final output = File(destination);
    expect(output.existsSync(), isTrue);
    final decoded = ZipDecoder().decodeBytes(await output.readAsBytes());
    final names = decoded.map((entry) => entry.name).toSet();
    expect(names, contains('database.sqlite'));
    expect(names, contains('profile.json'));
    await decoded.clear();
  });
}
