import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:bookmark_app/services/profile_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('case-folded archive path collision fails before target mutation', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_backup_casefold_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final archive = await _writeArchive(
      sandbox: sandbox,
      filename: 'casefold.zip',
      entries: [
        ArchiveFile.string('database.sqlite', 'database'),
        ArchiveFile.string('DATABASE.SQLITE', 'replacement'),
      ],
    );

    await _expectPreflightFailurePreservesTarget(
      sandbox: sandbox,
      archive: archive,
      targetName: 'casefold-target',
    );
  });

  test('file then descendant path fails before target mutation', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_backup_file_prefix_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final archive = await _writeArchive(
      sandbox: sandbox,
      filename: 'file_then_child.zip',
      entries: [
        ArchiveFile.string('database.sqlite', 'database'),
        ArchiveFile.string('attachments', 'not-a-directory'),
        ArchiveFile.string('attachments/file.pdf', 'child'),
      ],
    );

    await _expectPreflightFailurePreservesTarget(
      sandbox: sandbox,
      archive: archive,
      targetName: 'file-then-child-target',
    );
  });

  test('descendant then file path fails before target mutation', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_backup_child_prefix_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final archive = await _writeArchive(
      sandbox: sandbox,
      filename: 'child_then_file.zip',
      entries: [
        ArchiveFile.string('database.sqlite', 'database'),
        ArchiveFile.string('attachments/file.pdf', 'child'),
        ArchiveFile.string('attachments', 'not-a-directory'),
      ],
    );

    await _expectPreflightFailurePreservesTarget(
      sandbox: sandbox,
      archive: archive,
      targetName: 'child-then-file-target',
    );
  });
}

Future<void> _expectPreflightFailurePreservesTarget({
  required Directory sandbox,
  required File archive,
  required String targetName,
}) async {
  final target = Directory('${sandbox.path}/$targetName');
  await target.create();
  final sentinel = File('${target.path}/keep.txt');
  await sentinel.writeAsString('keep');

  await expectLater(
    const ProfileBackupService().restoreProfile(
      archivePath: archive.path,
      targetDirectoryPath: target.path,
    ),
    throwsA(isA<FormatException>()),
  );

  expect(await sentinel.readAsString(), 'keep');
}

Future<File> _writeArchive({
  required Directory sandbox,
  required String filename,
  required List<ArchiveFile> entries,
}) async {
  final archive = Archive();
  for (final entry in entries) {
    archive.add(entry);
  }
  final file = File('${sandbox.path}/$filename');
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  await archive.clear();
  return file;
}
