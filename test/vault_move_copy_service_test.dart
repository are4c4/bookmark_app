import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_move_copy_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DatabaseProfile> _createSource(
  Directory sandbox, {
  bool validDatabase = true,
}) async {
  final source = Directory('${sandbox.path}/Source Vault');
  await Directory('${source.path}/photos').create(recursive: true);
  await Directory('${source.path}/attachments').create(recursive: true);
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
  await File('${source.path}/database.sqlite').writeAsBytes(
    validDatabase
        ? [...'SQLite format 3\u0000'.codeUnits, 0, 1, 2, 3]
        : 'not sqlite'.codeUnits,
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
    sandbox = await Directory.systemTemp.createTemp('vault_move_copy_');
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('copies a complete prepared Vault and keeps the source untouched', () async {
    final profile = await _createSource(sandbox);
    final target = Directory('${sandbox.path}/Target Vault');
    final sourceMarker = File('${profile.directoryPath}/keep.txt');
    await sourceMarker.writeAsString('source stays');

    final moved = await const VaultMoveCopyService().copyPreparedVault(
      profile: profile,
      targetDirectoryPath: target.path,
    );

    expect(moved.id, profile.id);
    expect(moved.name, profile.name);
    expect(moved.databaseName, profile.databaseName);
    expect(moved.directoryPath, target.path);
    expect(File('${target.path}/database.sqlite').existsSync(), isTrue);
    expect(File('${target.path}/profile.json').existsSync(), isTrue);
    expect(await File('${target.path}/photos/photo.jpg').readAsBytes(), [1, 2, 3, 4]);
    expect(await File('${target.path}/attachments/note.txt').readAsString(), 'attachment');
    expect(await File('${target.path}/keep.txt').readAsString(), 'source stays');
    expect(await sourceMarker.readAsString(), 'source stays');
    expect(Directory(profile.directoryPath).existsSync(), isTrue);
  });

  test('validation failure removes a newly created target but never the source',
      () async {
    final profile = await _createSource(sandbox, validDatabase: false);
    final target = Directory('${sandbox.path}/Invalid Target');
    final sourceDatabase = File(profile.databasePath);
    final before = await sourceDatabase.readAsBytes();

    await expectLater(
      const VaultMoveCopyService().copyPreparedVault(
        profile: profile,
        targetDirectoryPath: target.path,
      ),
      throwsA(isA<FormatException>()),
    );

    expect(target.existsSync(), isFalse);
    expect(await sourceDatabase.readAsBytes(), before);
    expect(Directory(profile.directoryPath).existsSync(), isTrue);
  });

  test('validation failure preserves an existing empty target root', () async {
    final profile = await _createSource(sandbox, validDatabase: false);
    final target = Directory('${sandbox.path}/Existing Empty Target');
    await target.create(recursive: true);

    await expectLater(
      const VaultMoveCopyService().copyPreparedVault(
        profile: profile,
        targetDirectoryPath: target.path,
      ),
      throwsA(isA<FormatException>()),
    );

    expect(target.existsSync(), isTrue);
    expect(await target.list().isEmpty, isTrue);
    expect(Directory(profile.directoryPath).existsSync(), isTrue);
  });

  test('preflight refusal leaves a non-empty target unchanged', () async {
    final profile = await _createSource(sandbox);
    final target = Directory('${sandbox.path}/Occupied Target');
    await target.create(recursive: true);
    final marker = File('${target.path}/keep.txt');
    await marker.writeAsString('user data');

    await expectLater(
      const VaultMoveCopyService().copyPreparedVault(
        profile: profile,
        targetDirectoryPath: target.path,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await marker.readAsString(), 'user data');
    expect(Directory(profile.directoryPath).existsSync(), isTrue);
  });

  test('does not follow a source symbolic link outside the Vault', () async {
    final profile = await _createSource(sandbox);
    final outside = File('${sandbox.path}/outside.txt');
    await outside.writeAsString('external');
    final link = Link('${profile.directoryPath}/outside-link');
    try {
      await link.create(outside.path);
    } on FileSystemException {
      return;
    }
    final target = Directory('${sandbox.path}/Target');

    await expectLater(
      const VaultMoveCopyService().copyPreparedVault(
        profile: profile,
        targetDirectoryPath: target.path,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await outside.readAsString(), 'external');
    expect(target.existsSync(), isFalse);
  });
}
