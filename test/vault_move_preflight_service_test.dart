import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_move_preflight_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DatabaseProfile> _createVault(Directory sandbox) async {
  final source = Directory('${sandbox.path}/Source Vault');
  await Directory('${source.path}/photos').create(recursive: true);
  await Directory('${source.path}/attachments').create(recursive: true);
  await File('${source.path}/database.sqlite').writeAsBytes(List.filled(32, 1));
  await File('${source.path}/profile.json').writeAsString(
    jsonEncode({
      'formatVersion': 1,
      'id': 'move-vault',
      'name': 'Move Vault',
      'database': 'database.sqlite',
      'photos': 'photos',
      'attachments': 'attachments',
    }),
  );
  await File('${source.path}/photos/photo.jpg').writeAsBytes([1, 2, 3, 4]);
  await File('${source.path}/attachments/note.txt').writeAsString('attachment');
  return DatabaseProfile(
    id: 'move-vault',
    name: 'Move Vault',
    databaseName: 'BookmarkApp/Profiles/move-vault/database',
    directoryPath: source.path,
  );
}

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('vault_move_preflight_');
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('plans a move without creating a missing target directory', () async {
    final profile = await _createVault(sandbox);
    final target = Directory('${sandbox.path}/Target Vault');

    final plan = await const VaultMovePreflightService().plan(
      profile: profile,
      targetDirectoryPath: target.path,
    );

    expect(plan.sourceDirectoryPath, profile.directoryPath);
    expect(plan.targetDirectoryPath, target.path);
    expect(plan.targetDirectoryAlreadyExists, isFalse);
    expect(plan.fileCount, 4);
    expect(plan.totalBytes, greaterThan(0));
    expect(target.existsSync(), isFalse);
  });

  test('accepts an existing empty target without modifying it', () async {
    final profile = await _createVault(sandbox);
    final target = Directory('${sandbox.path}/Empty Target');
    await target.create(recursive: true);

    final plan = await const VaultMovePreflightService().plan(
      profile: profile,
      targetDirectoryPath: target.path,
    );

    expect(plan.targetDirectoryAlreadyExists, isTrue);
    expect(await target.list().isEmpty, isTrue);
  });

  test('rejects a non-empty target and preserves its contents', () async {
    final profile = await _createVault(sandbox);
    final target = Directory('${sandbox.path}/Occupied Target');
    await target.create(recursive: true);
    final marker = File('${target.path}/keep.txt');
    await marker.writeAsString('keep me');

    await expectLater(
      const VaultMovePreflightService().plan(
        profile: profile,
        targetDirectoryPath: target.path,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await marker.readAsString(), 'keep me');
  });

  test('rejects a target nested inside the source Vault', () async {
    final profile = await _createVault(sandbox);
    final nested = '${profile.directoryPath}/nested-target';

    await expectLater(
      const VaultMovePreflightService().plan(
        profile: profile,
        targetDirectoryPath: nested,
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(Directory(nested).existsSync(), isFalse);
  });

  test('rejects an incomplete source without creating the target', () async {
    final source = Directory('${sandbox.path}/Incomplete Source');
    await source.create(recursive: true);
    final profile = DatabaseProfile(
      id: 'incomplete',
      name: 'Incomplete',
      databaseName: 'incomplete-db',
      directoryPath: source.path,
    );
    final target = Directory('${sandbox.path}/Target');

    await expectLater(
      const VaultMovePreflightService().plan(
        profile: profile,
        targetDirectoryPath: target.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(target.existsSync(), isFalse);
  });

  test('rejects symbolic links before any target mutation', () async {
    final profile = await _createVault(sandbox);
    final outside = File('${sandbox.path}/outside.txt');
    await outside.writeAsString('external');
    final link = Link('${profile.directoryPath}/external-link');
    try {
      await link.create(outside.path);
    } on FileSystemException {
      return;
    }
    final target = Directory('${sandbox.path}/Target');

    await expectLater(
      const VaultMovePreflightService().plan(
        profile: profile,
        targetDirectoryPath: target.path,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await outside.readAsString(), 'external');
    expect(target.existsSync(), isFalse);
  });
}
