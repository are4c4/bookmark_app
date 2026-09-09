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
    await File('${attachments.path}/notes.txt')
        .writeAsString('portable attachment');

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

  test(
    'profile-relative managed paths resolve under a restored Vault root',
    () async {
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
    },
  );

  test(
    'unsafe archive member paths fail before an existing target is mutated',
    () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'bookmark_profile_backup_unsafe_path_',
      );
      addTearDown(() async {
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      for (final unsafePath in <String>[
        '../outside.txt',
        '/tmp/outside.txt',
        'C:/Users/example/outside.txt',
      ]) {
        final archive = await _writeArchive(
          sandbox: sandbox,
          filename: 'unsafe_${unsafePath.hashCode}.zip',
          entries: [
            ArchiveFile.string('database.sqlite', 'database'),
            ArchiveFile.string(unsafePath, 'outside'),
          ],
        );
        final target = Directory(
          '${sandbox.path}/target_${unsafePath.hashCode}',
        );
        await target.create();
        final sentinel = File('${target.path}/keep.txt');
        await sentinel.writeAsString('keep');

        await expectLater(
          const ProfileBackupService().restoreProfile(
            archivePath: archive.path,
            targetDirectoryPath: target.path,
          ),
          throwsA(isA<FormatException>()),
          reason: unsafePath,
        );

        expect(await sentinel.readAsString(), 'keep', reason: unsafePath);
      }
    },
  );

  test(
    'symlinked backup fails before extraction and preserves target',
    () async {
      if (Platform.isWindows) return;

      final sandbox = await Directory.systemTemp.createTemp(
        'bookmark_profile_backup_symlink_',
      );
      addTearDown(() async {
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      final archive = await _writeArchive(
        sandbox: sandbox,
        filename: 'symlink.zip',
        entries: [
          ArchiveFile.string('database.sqlite', 'database'),
          _zipSymlink('attachments/link', '../database.sqlite'),
        ],
      );
      final target = Directory('${sandbox.path}/target');
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
      expect(Link('${target.path}/attachments/link').existsSync(), isFalse);
    },
  );

  test(
    'nested symlink-chain backup cannot write outside restore target',
    () async {
      if (Platform.isWindows) return;

      final sandbox = await Directory.systemTemp.createTemp(
        'bookmark_profile_backup_symlink_chain_',
      );
      addTearDown(() async {
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      final archive = await _writeArchive(
        sandbox: sandbox,
        filename: 'symlink_chain.zip',
        entries: [
          ArchiveFile.string('database.sqlite', 'database'),
          _zipSymlink('a/link', '../b'),
          _zipSymlink('a/link/escape', '../../outside'),
          ArchiveFile.string('a/link/escape/pwned.txt', 'do not write'),
        ],
      );
      final target = Directory('${sandbox.path}/target');
      await target.create();
      final sentinel = File('${target.path}/keep.txt');
      await sentinel.writeAsString('keep');
      final outside = File('${sandbox.path}/outside/pwned.txt');

      await expectLater(
        const ProfileBackupService().restoreProfile(
          archivePath: archive.path,
          targetDirectoryPath: target.path,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(await sentinel.readAsString(), 'keep');
      expect(outside.existsSync(), isFalse);
    },
  );

  test('missing top-level database fails before target mutation', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_backup_missing_database_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final archive = await _writeArchive(
      sandbox: sandbox,
      filename: 'missing_database.zip',
      entries: [ArchiveFile.string('profile.json', '{}')],
    );
    final target = Directory('${sandbox.path}/target');
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
  });
}

ArchiveFile _zipSymlink(String name, String target) {
  // ZipDecoder recognizes the Unix symlink file-type bits only when the ZIP
  // central directory also identifies the creator OS as Unix. The helper below
  // patches that creator byte after ZipEncoder writes the synthetic fixture.
  return ArchiveFile.string(name, target)..mode = 0xa000 | 0x1ff;
}

Future<File> _writeArchive({
  required Directory sandbox,
  required String filename,
  required List<ArchiveFile> entries,
}) async {
  final hasSyntheticSymlink = entries.any(
    (entry) => (entry.mode & 0xf000) == 0xa000,
  );
  final archive = Archive();
  for (final entry in entries) {
    archive.add(entry);
  }
  final bytes = ZipEncoder().encodeBytes(archive);
  if (hasSyntheticSymlink) {
    _markZipCreatorUnix(bytes);
  }
  final file = File('${sandbox.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await archive.clear();
  return file;
}

void _markZipCreatorUnix(List<int> bytes) {
  final end = _findEndOfCentralDirectory(bytes);
  final entryCount = _readUint16Le(bytes, end + 10);
  var offset = _readUint32Le(bytes, end + 16);

  for (var index = 0; index < entryCount; index++) {
    if (_readUint32Le(bytes, offset) != 0x02014b50) {
      throw StateError('Synthetic ZIP central directory is malformed.');
    }

    // Central-directory "version made by" is little-endian: low byte is the
    // ZIP version and high byte is the creator OS. Unix is creator OS 3.
    bytes[offset + 5] = 3;

    final nameLength = _readUint16Le(bytes, offset + 28);
    final extraLength = _readUint16Le(bytes, offset + 30);
    final commentLength = _readUint16Le(bytes, offset + 32);
    offset += 46 + nameLength + extraLength + commentLength;
  }
}

int _findEndOfCentralDirectory(List<int> bytes) {
  for (var offset = bytes.length - 22; offset >= 0; offset--) {
    if (_readUint32Le(bytes, offset) == 0x06054b50) {
      return offset;
    }
  }
  throw StateError('Synthetic ZIP has no end-of-central-directory record.');
}

int _readUint16Le(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _readUint32Le(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);
