import 'dart:developer' as developer;
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_selector/file_selector.dart';

import '../data/app_database.dart';

class ProfileBackupService {
  const ProfileBackupService();

  Future<String?> exportProfile({
    required String profileName,
    required String profileDirectoryPath,
    required AppDatabase database,
  }) async {
    await database.customStatement('PRAGMA wal_checkpoint(FULL)');

    final safeName = profileName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9ぁ-んァ-ヶ一-龠々ー_-]+'), '_');
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final location = await getSaveLocation(
      suggestedName:
          '${safeName.isEmpty ? 'BookmarkProfile' : safeName}_$date.bookmark-profile.zip',
    );
    if (location == null) return null;

    final directory = Directory(profileDirectoryPath);
    if (!await directory.exists()) {
      throw StateError('Vaultフォルダが見つかりません。');
    }

    await ZipFileEncoder().zipDirectory(
      directory,
      filename: location.path,
      followLinks: false,
    );
    return location.path;
  }

  Future<String?> pickBackupFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Bookmark Vault backup',
          extensions: ['zip'],
        ),
      ],
    );
    return file?.path;
  }

  Future<void> restoreProfile({
    required String archivePath,
    required String targetDirectoryPath,
  }) async {
    final archive = File(archivePath);
    if (!await archive.exists()) {
      throw StateError('バックアップファイルが見つかりません。');
    }

    // Validate the complete archive member namespace before touching the
    // restore target. Bookmark Vault backups do not need symbolic links, so
    // accepting them would grant unnecessary filesystem authority during
    // extraction.
    await _validateRestoreArchive(archive.path);

    final target = Directory(targetDirectoryPath);
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);

    try {
      await extractFileToDisk(archive.path, target.path);
      if (!await File('${target.path}/database.sqlite').exists()) {
        throw const FormatException(
          'database.sqliteを含むBookmark Vaultバックアップではありません。',
        );
      }
    } catch (_) {
      // Cleanup is best-effort. A cleanup failure must not replace the original
      // extraction/validation failure that explains why restore failed.
      try {
        if (await target.exists()) {
          await target.delete(recursive: true);
        }
      } catch (_, stackTrace) {
        assert(() {
          developer.log(
            'Profile restore cleanup failed.',
            name: 'bookmark_app.profile_backup',
            stackTrace: stackTrace,
          );
          return true;
        }());
      }
      rethrow;
    }
  }

  Future<void> _validateRestoreArchive(String archivePath) async {
    final input = InputFileStream(archivePath);
    Archive? decoded;
    try {
      decoded = ZipDecoder().decodeStream(input);
      final memberKindsByFoldedPath = <String, bool>{};
      var databaseEntries = 0;

      for (final entry in decoded) {
        if (entry.isSymbolicLink) {
          throw const FormatException(
            'シンボリックリンクを含むBookmark Vaultバックアップは復元できません。',
          );
        }

        final memberPath = _validatedArchiveMemberPath(entry);
        final foldedPath = memberPath.toLowerCase();
        if (memberKindsByFoldedPath.containsKey(foldedPath)) {
          throw FormatException(
            '大文字小文字を区別しない重複パスを含むBookmark Vaultバックアップは復元できません: '
            '$memberPath',
          );
        }

        final isRegularFile = entry.isFile && !entry.isDirectory;
        for (final existing in memberKindsByFoldedPath.entries) {
          if (foldedPath.startsWith('${existing.key}/') && existing.value) {
            throw FormatException(
              '通常ファイル配下に子パスを含むBookmark Vaultバックアップは復元できません: '
              '$memberPath',
            );
          }
          if (existing.key.startsWith('$foldedPath/') && isRegularFile) {
            throw FormatException(
              '子パスを持つ通常ファイルを含むBookmark Vaultバックアップは復元できません: '
              '$memberPath',
            );
          }
        }
        memberKindsByFoldedPath[foldedPath] = isRegularFile;

        if (memberPath == 'database.sqlite') {
          databaseEntries++;
          if (!isRegularFile) {
            throw const FormatException('database.sqliteが通常ファイルではありません。');
          }
        }
      }

      if (databaseEntries != 1) {
        throw const FormatException(
          'database.sqliteを1つ含むBookmark Vaultバックアップではありません。',
        );
      }
    } finally {
      if (decoded != null) {
        await decoded.clear();
      }
      await input.close();
    }
  }

  String _validatedArchiveMemberPath(ArchiveFile entry) {
    var memberPath = entry.name;
    if (memberPath.isEmpty || memberPath.contains('\u0000')) {
      throw const FormatException('空または不正なバックアップパスです。');
    }
    if (memberPath.contains('\\')) {
      throw const FormatException('バックスラッシュを含むバックアップパスは復元できません。');
    }
    if (memberPath.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(memberPath)) {
      throw const FormatException('絶対パスを含むBookmark Vaultバックアップは復元できません。');
    }

    if (entry.isDirectory && memberPath.endsWith('/')) {
      memberPath = memberPath.substring(0, memberPath.length - 1);
    }
    if (memberPath.isEmpty || memberPath.endsWith('/')) {
      throw const FormatException('不正なバックアップディレクトリパスです。');
    }

    final segments = memberPath.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw const FormatException('パストラバーサルを含むBookmark Vaultバックアップは復元できません。');
    }
    return memberPath;
  }
}
