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
      throw StateError('Profileフォルダが見つかりません。');
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
          label: 'Bookmark Profile backup',
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

    final target = Directory(targetDirectoryPath);
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);

    try {
      await extractFileToDisk(archive.path, target.path);
      if (!await File('${target.path}/database.sqlite').exists()) {
        throw const FormatException(
          'database.sqliteを含むBookmark Profileバックアップではありません。',
        );
      }
    } catch (_) {
      if (await target.exists()) {
        await target.delete(recursive: true);
      }
      rethrow;
    }
  }
}
