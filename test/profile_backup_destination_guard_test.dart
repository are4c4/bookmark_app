import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/services/profile_backup_service.dart';
import 'package:bookmark_app/services/vault_backup_destination_guard.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Directory> _createSandbox(String prefix) async {
  final sandbox = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });
  return sandbox;
}

AppDatabase _databaseFor(Directory vault) {
  final database = AppDatabase.forTesting(
    NativeDatabase.memory(),
    profileDirectoryPath: vault.path,
  );
  addTearDown(database.close);
  return database;
}

ProfileBackupService _serviceFor(String? destination) {
  return ProfileBackupService(
    exportDestinationPicker: (_) async => destination,
  );
}

void main() {
  const guard = VaultBackupDestinationGuard();

  test(
    'rejects direct and nested destinations inside the source Vault',
    () async {
      final sandbox = await _createSandbox(
        'bookmark_vault_backup_destination_inside_',
      );
      final vault = Directory('${sandbox.path}/vault');
      await Directory('${vault.path}/photos').create(recursive: true);
      await Directory('${vault.path}/attachments/nested')
          .create(recursive: true);

      for (final destination in <String>[
        '${vault.path}/backup.zip',
        '${vault.path}/photos/backup.zip',
        '${vault.path}/attachments/nested/backup.zip',
      ]) {
        await expectLater(
          guard.resolveSafeDestination(
            sourceVaultPath: vault.path,
            destinationPath: destination,
          ),
          throwsA(isA<FileSystemException>()),
          reason: destination,
        );
        expect(File(destination).existsSync(), isFalse, reason: destination);
      }
    },
  );

  test(
    'allows an ordinary sibling destination outside the source Vault',
    () async {
      final sandbox = await _createSandbox(
        'bookmark_vault_backup_destination_outside_',
      );
      final vault = Directory('${sandbox.path}/vault');
      await vault.create();
      final destination = '${sandbox.path}/backup.zip';

      final resolved = await guard.resolveSafeDestination(
        sourceVaultPath: vault.path,
        destinationPath: destination,
      );

      expect(File(resolved).absolute.path, File(destination).absolute.path);
    },
  );

  test(
    'rejects a destination whose parent symlink resolves into the Vault',
    () async {
      if (Platform.isWindows) return;

      final sandbox = await _createSandbox(
        'bookmark_vault_backup_destination_parent_link_',
      );
      final vault = Directory('${sandbox.path}/vault');
      await vault.create();
      final alias = Link('${sandbox.path}/vault-alias');
      await alias.create(vault.path);

      await expectLater(
        guard.resolveSafeDestination(
          sourceVaultPath: vault.path,
          destinationPath: '${alias.path}/backup.zip',
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(File('${vault.path}/backup.zip').existsSync(), isFalse);
    },
  );

  test('rejects an existing destination symlink targeting the Vault', () async {
    if (Platform.isWindows) return;

    final sandbox = await _createSandbox(
      'bookmark_vault_backup_destination_file_link_',
    );
    final vault = Directory('${sandbox.path}/vault');
    await vault.create();
    final target = File('${vault.path}/existing.zip');
    await target.writeAsBytes([1, 2, 3]);
    final destination = Link('${sandbox.path}/backup.zip');
    await destination.create(target.path);

    await expectLater(
      guard.resolveSafeDestination(
        sourceVaultPath: vault.path,
        destinationPath: destination.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.readAsBytes(), [1, 2, 3]);
  });

  test(
    'export rejects a Vault-local destination before checkpoint/output',
    () async {
      final sandbox = await _createSandbox(
        'bookmark_profile_backup_inside_guard_',
      );
      final vault = Directory('${sandbox.path}/vault');
      await vault.create();
      final sentinel = File('${vault.path}/keep.txt');
      await sentinel.writeAsString('keep');
      final database = _databaseFor(vault);
      final destination = '${vault.path}/backup.zip';

      await expectLater(
        _serviceFor(destination).exportProfile(
          profileName: 'Vault',
          profileDirectoryPath: vault.path,
          database: database,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(File(destination).existsSync(), isFalse);
      expect(File('${vault.path}/database.sqlite').existsSync(), isFalse);
      expect(await sentinel.readAsString(), 'keep');
    },
  );

  test(
    'export cancellation returns null without checkpointing the Vault',
    () async {
      final sandbox = await _createSandbox('bookmark_profile_backup_cancel_');
      final vault = Directory('${sandbox.path}/vault');
      await vault.create();
      final database = _databaseFor(vault);

      final result = await _serviceFor(null).exportProfile(
        profileName: 'Vault',
        profileDirectoryPath: vault.path,
        database: database,
      );

      expect(result, isNull);
      expect(File('${vault.path}/database.sqlite').existsSync(), isFalse);
    },
  );

  test(
    'export still writes a complete backup to an outside destination',
    () async {
      final sandbox = await _createSandbox(
        'bookmark_profile_backup_outside_guard_',
      );
      final vault = Directory('${sandbox.path}/vault');
      await vault.create();
      await File('${vault.path}/database.sqlite').writeAsBytes([1, 2, 3]);
      await File('${vault.path}/profile.json').writeAsString('{}');
      final database = _databaseFor(vault);
      final destination = '${sandbox.path}/backup.zip';

      final result = await _serviceFor(destination).exportProfile(
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
    },
  );

  test(
    'export replaces an outside hard link without mutating its Vault inode',
    () async {
      if (Platform.isWindows) return;

      final sandbox = await _createSandbox(
        'bookmark_profile_backup_hard_link_',
      );
      final vault = Directory('${sandbox.path}/vault');
      await vault.create();
      final source = File('${vault.path}/preserved.bin');
      final sourceBytes = <int>[11, 22, 33, 44];
      await source.writeAsBytes(sourceBytes);
      final destination = File('${sandbox.path}/backup.zip');
      final linkResult = await Process.run('ln', [
        source.path,
        destination.path,
      ]);
      expect(linkResult.exitCode, 0, reason: '${linkResult.stderr}');
      final database = _databaseFor(vault);

      final result = await _serviceFor(destination.path).exportProfile(
        profileName: 'Vault',
        profileDirectoryPath: vault.path,
        database: database,
      );

      expect(result, destination.path);
      expect(await source.readAsBytes(), sourceBytes);
      expect(await destination.readAsBytes(), isNot(sourceBytes));
      expect(
        await FileSystemEntity.type(destination.path, followLinks: false),
        FileSystemEntityType.file,
      );
    },
  );

  test(
    'export replaces an outside symlink without writing through its target',
    () async {
      if (Platform.isWindows) return;

      final sandbox = await _createSandbox(
        'bookmark_profile_backup_external_link_',
      );
      final vault = Directory('${sandbox.path}/vault');
      await vault.create();
      final target = File('${sandbox.path}/existing-target.bin');
      final targetBytes = <int>[5, 4, 3, 2, 1];
      await target.writeAsBytes(targetBytes);
      final destination = Link('${sandbox.path}/backup.zip');
      await destination.create(target.path);
      final database = _databaseFor(vault);

      final result = await _serviceFor(destination.path).exportProfile(
        profileName: 'Vault',
        profileDirectoryPath: vault.path,
        database: database,
      );

      expect(result, destination.path);
      expect(await target.readAsBytes(), targetBytes);
      expect(
        await FileSystemEntity.type(destination.path, followLinks: false),
        FileSystemEntityType.file,
      );
    },
  );
}
