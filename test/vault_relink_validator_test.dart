import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_relink_validator.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseProfile _profile(String path) => DatabaseProfile(
      id: 'portable-vault',
      name: 'Portable Vault',
      databaseName: 'BookmarkApp/Profiles/portable-vault/database',
      directoryPath: path,
    );

Future<void> _writeMetadata(
  Directory directory, {
  String id = 'portable-vault',
}) =>
    File('${directory.path}/profile.json').writeAsString(
      jsonEncode({
        'formatVersion': 1,
        'id': id,
        'name': 'Portable Vault',
        'database': 'database.sqlite',
        'photos': 'photos',
        'attachments': 'attachments',
      }),
    );

Future<void> _writeSqliteHeader(Directory directory) async {
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

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('vault_relink_validator_');
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('accepts the same Vault id at a new compatible location', () async {
    final oldPath = '${sandbox.path}/old-location';
    final candidate = Directory('${sandbox.path}/new-location');
    await candidate.create(recursive: true);
    await _writeMetadata(candidate);
    await _writeSqliteHeader(candidate);
    final marker = File('${candidate.path}/keep.txt');
    await marker.writeAsString('unchanged');

    final validated = await const VaultRelinkValidator().validate(
      expectedProfile: _profile(oldPath),
      directoryPath: candidate.path,
    );

    expect(validated.id, 'portable-vault');
    expect(validated.name, 'Portable Vault');
    expect(validated.databaseName, 'BookmarkApp/Profiles/portable-vault/database');
    expect(validated.directoryPath, candidate.path);
    expect(await marker.readAsString(), 'unchanged');
  });

  test('rejects a different Vault id without mutating the candidate', () async {
    final candidate = Directory('${sandbox.path}/different-vault');
    await candidate.create(recursive: true);
    await _writeMetadata(candidate, id: 'another-vault');
    await _writeSqliteHeader(candidate);
    final before = await File('${candidate.path}/profile.json').readAsString();

    await expectLater(
      const VaultRelinkValidator().validate(
        expectedProfile: _profile('${sandbox.path}/missing-old'),
        directoryPath: candidate.path,
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await File('${candidate.path}/profile.json').readAsString(), before);
  });

  test('rejects a candidate without database.sqlite', () async {
    final candidate = Directory('${sandbox.path}/missing-db');
    await candidate.create(recursive: true);
    await _writeMetadata(candidate);

    await expectLater(
      const VaultRelinkValidator().validate(
        expectedProfile: _profile('${sandbox.path}/missing-old'),
        directoryPath: candidate.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(File('${candidate.path}/database.sqlite').existsSync(), isFalse);
  });

  test('rejects a non-SQLite database file without rewriting it', () async {
    final candidate = Directory('${sandbox.path}/invalid-db');
    await candidate.create(recursive: true);
    await _writeMetadata(candidate);
    final database = File('${candidate.path}/database.sqlite');
    await database.writeAsString('not sqlite');

    await expectLater(
      const VaultRelinkValidator().validate(
        expectedProfile: _profile('${sandbox.path}/missing-old'),
        directoryPath: candidate.path,
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await database.readAsString(), 'not sqlite');
  });
}
