import 'dart:io';

import 'profile_manager.dart';

class VaultMovePlan {
  const VaultMovePlan({
    required this.sourceDirectoryPath,
    required this.targetDirectoryPath,
    required this.targetDirectoryAlreadyExists,
    required this.fileCount,
    required this.totalBytes,
  });

  final String sourceDirectoryPath;
  final String targetDirectoryPath;
  final bool targetDirectoryAlreadyExists;
  final int fileCount;
  final int totalBytes;
}

class VaultMovePreflightService {
  const VaultMovePreflightService();

  Future<VaultMovePlan> plan({
    required DatabaseProfile profile,
    required String targetDirectoryPath,
  }) async {
    final trimmedTarget = targetDirectoryPath.trim();
    if (trimmedTarget.isEmpty) {
      throw ArgumentError('Vault target directory is empty');
    }

    final source = Directory(profile.directoryPath);
    final target = Directory(trimmedTarget);
    final sourcePath = _normalizedAbsolutePath(source.path);
    final targetPath = _normalizedAbsolutePath(target.path);

    if (sourcePath == targetPath) {
      throw ArgumentError('Vault source and target directories are identical');
    }
    if (_isInside(targetPath, sourcePath)) {
      throw ArgumentError('Vault target cannot be inside the source Vault');
    }
    if (!await source.exists()) {
      throw FileSystemException('Vault source directory is unavailable.', source.path);
    }
    if (!await File(profile.databasePath).exists()) {
      throw FileSystemException('Vault source database is unavailable.', profile.databasePath);
    }
    if (!await File(profile.profileMetadataPath).exists()) {
      throw FileSystemException(
        'Vault source metadata is unavailable.',
        profile.profileMetadataPath,
      );
    }

    final targetExists = await target.exists();
    if (targetExists && !await target.list(followLinks: false).isEmpty) {
      throw FileSystemException(
        'Vault move target must be empty.',
        target.path,
      );
    }

    var fileCount = 0;
    var totalBytes = 0;
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Link) {
        throw FileSystemException(
          'Vault contains an unsupported symbolic link.',
          entity.path,
        );
      }
      if (entity is File) {
        fileCount++;
        totalBytes += await entity.length();
      }
    }

    return VaultMovePlan(
      sourceDirectoryPath: source.path,
      targetDirectoryPath: target.path,
      targetDirectoryAlreadyExists: targetExists,
      fileCount: fileCount,
      totalBytes: totalBytes,
    );
  }

  String _normalizedAbsolutePath(String path) => Directory(path)
      .absolute
      .path
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '');

  bool _isInside(String path, String root) => path.startsWith('$root/');
}
