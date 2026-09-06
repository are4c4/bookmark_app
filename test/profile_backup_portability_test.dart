import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/services/profile_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile restore preserves a complete portable Vault data set', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_backup_portability_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final source = Directory('${sandbox.path}/source');
    final photos = Directory('${source.path}/photos');
    final attachments = Directory('${source.path}/attachments');
    await photos.create(recursive: true);
    await attachments.create(recursive: true);

    await File('${source.path}/database.sqlite').writeAsBytes([1, 2, 3, 4]);
    await File('${source.path}/profile.json').writeAsString(
      jsonEncode({
        'formatVersion': 1,
        'id': 'portable-vault',
        'name': 'Portable Vault',
        'database': 'database.sqlite',
        'photos': 'photos',
        'attachments': 'attachments',
      }),
    );
    await File('${photos.path}/cover.jpg').writeAsBytes([5, 6, 7]);
    await File('${attachments.path}/notes.txt').writeAsString('portable attachment');

    final archive = File('${sandbox.path}/vault.zip');
    await ZipFileEncoder().zipDirectory(
      source,
      filename: archive.path,
      followLinks: false,
    );

    final target = Directory('${sandbox.path}/restored');
    await const ProfileBackupService().restoreProfile(
      archivePath: archive.path,
      targetDirectoryPath: target.path,
    );

    expect(
      await File('${target.path}/database.sqlite').readAsBytes(),
      [1, 2, 3, 4],
    );
    expect(File('${target.path}/profile.json').existsSync(), isTrue);
    expect(
      await File('${target.path}/photos/cover.jpg').readAsBytes(),
      [5, 6, 7],
    );
    expect(
      await File('${target.path}/attachments/notes.txt').readAsString(),
      'portable attachment',
    );
  });

  test('profile-relative managed paths resolve under a restored Vault root', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_relative_restore_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final restored = Directory('${sandbox.path}/restored-vault');
    await Directory('${restored.path}/photos').create(recursive: true);
    await Directory('${restored.path}/attachments').create(recursive: true);
    await File('${restored.path}/photos/image.png').writeAsBytes([1]);
    await File('${restored.path}/attachments/file.pdf').writeAsBytes([2]);

    final resolver = ProfilePathResolver(restored.path);

    expect(
      resolver.resolveStoredPath('photos/image.png'),
      '${restored.path}/photos/image.png',
    );
    expect(
      resolver.resolveStoredPath('attachments/file.pdf'),
      '${restored.path}/attachments/file.pdf',
    );
    expect(
      File(resolver.resolveStoredPath('photos/image.png')).existsSync(),
      isTrue,
    );
    expect(
      File(resolver.resolveStoredPath('attachments/file.pdf')).existsSync(),
      isTrue,
    );
  });
}
