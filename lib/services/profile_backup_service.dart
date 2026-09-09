import 'dart:developer' as developer;
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_selector/file_selector.dart';

import '../data/app_database.dart';
import 'vault_backup_destination_guard.dart';

typedef ProfileBackupDestinationPicker =
    Future<String?> Function(String suggestedName);

class ProfileBackupService {
  const ProfileBackupService({this.exportDestinationPicker});

  final ProfileBackupDestinationPicker? exportDestinationPicker;

  Future<String?> exportProfile({
    required String profileName,
    required String profileDirectoryPath,
    required AppDatabase database,
  }) async {
    final safeName = profileName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9ぁ-んァ-ヶ一-龠々ー_-]+'), '_');
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final suggestedName =
        '${safeName.isEmpty ? 'BookmarkProfile' : safeName}_$date.bookmark-profile.zip';
    final destinationPath = await _pickExportDestination(suggestedName);
    if (destinationPath == null) return null;

    final directory = Directory(profileDirectoryPath);
    if (!await directory.exists()) {
      throw StateError('Vaultフォルダが見つかりません。');
    }

    // Complete backup must remain a read-only operation with respect to the
    // source Vault. Prove the output cannot resolve into the recursively read
    // source tree before checkpointing or creating the archive.
    await const VaultBackupDestinationGuard().validate(
      sourceVaultPath: directory.path,
      destinationPath: destinationPath,
    );

    await database.customStatement('PRAGMA wal_checkpoint(FULL)');
    await ZipFileEncoder().zipDirectory(
      directory,
      filename: destinationPath,
      followLinks: false,
    );
    return destinationPath;
  }

  Future<String?> _pickExportDestination(String suggestedName) async {
    final picker = exportDestinationPicker;
    if (picker != null) return picker(suggestedName);
    return (await getSaveLocation(suggestedName: suggestedName))?.path;
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
      await _extractRestoreArchive(archive.path, target.path);
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
      _validateDecodedRestoreArchive(decoded);
    } finally {
      if (decoded != null) {
        await decoded.clear();
      }
      await input.close();
    }
  }

  void _validateDecodedRestoreArchive(Archive decoded) {
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
  }

  Future<void> _extractRestoreArchive(
    String archivePath,
    String targetDirectoryPath,
  ) async {
    final input = InputFileStream(archivePath);
    Archive? decoded;
    try {
      decoded = ZipDecoder().decodeStream(input);
      // The archive can live outside the Vault and could be replaced between
      // the preflight and extraction pass. Reapply the complete namespace
      // contract before this decoded snapshot writes any target bytes.
      _validateDecodedRestoreArchive(decoded);

      for (final entry in decoded) {
        final memberPath = _validatedArchiveMemberPath(entry);
        final destinationPath = _resolveRestoreMemberPath(
          targetDirectoryPath: targetDirectoryPath,
          memberPath: memberPath,
        );

        if (entry.isDirectory) {
          await Directory(destinationPath).create(recursive: true);
          continue;
        }

        final destination = File(destinationPath);
        await destination.parent.create(recursive: true);
        await _writeArchiveFile(entry, destination.path);
      }
    } finally {
      if (decoded != null) {
        await decoded.clear();
      }
      await input.close();
    }
  }

  Future<void> _writeArchiveFile(ArchiveFile entry, String outputPath) async {
    final output = OutputFileStream(outputPath);
    Object? writeFailure;
    StackTrace? writeFailureStackTrace;
    try {
      entry.writeContent(output);
    } catch (error, stackTrace) {
      writeFailure = error;
      writeFailureStackTrace = stackTrace;
    }

    try {
      await output.close();
    } catch (error, stackTrace) {
      if (writeFailure == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    if (writeFailure != null) {
      Error.throwWithStackTrace(writeFailure, writeFailureStackTrace!);
    }
  }

  String _resolveRestoreMemberPath({
    required String targetDirectoryPath,
    required String memberPath,
  }) {
    final targetRoot = _normalizedAbsoluteDirectory(targetDirectoryPath);
    final destination = _normalizedAbsoluteFile('$targetRoot/$memberPath');
    final prefix = targetRoot.endsWith('/') ? targetRoot : '$targetRoot/';
    if (!destination.startsWith(prefix)) {
      throw const FormatException('復元先の外側を指すBookmark Vaultバックアップパスです。');
    }
    return destination;
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

  String _normalizedAbsoluteDirectory(String path) {
    final normalized = Directory(path).absolute.path.replaceAll('\\', '/');
    if (normalized == '/' || RegExp(r'^[A-Za-z]:/$').hasMatch(normalized)) {
      return normalized;
    }
    return normalized.replaceAll(RegExp(r'/+$'), '');
  }

  String _normalizedAbsoluteFile(String path) =>
      File(path).absolute.path.replaceAll('\\', '/');
}
