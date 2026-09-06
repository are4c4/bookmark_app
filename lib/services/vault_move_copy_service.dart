import 'dart:io';

import 'profile_manager.dart';
import 'vault_move_preflight_service.dart';
import 'vault_relink_validator.dart';

class VaultMoveCopyService {
  const VaultMoveCopyService({
    this.preflight = const VaultMovePreflightService(),
    this.validator = const VaultRelinkValidator(),
  });

  final VaultMovePreflightService preflight;
  final VaultRelinkValidator validator;

  Future<DatabaseProfile> copyPreparedVault({
    required DatabaseProfile profile,
    required String targetDirectoryPath,
  }) async {
    final plan = await preflight.plan(
      profile: profile,
      targetDirectoryPath: targetDirectoryPath,
    );
    final source = Directory(plan.sourceDirectoryPath);
    final target = Directory(plan.targetDirectoryPath);
    final createdFiles = <File>[];
    final createdDirectories = <Directory>[];
    final createdRoot = !plan.targetDirectoryAlreadyExists;

    if (createdRoot) {
      await target.create(recursive: true);
    }

    try {
      await _copyDirectoryContents(
        source: source,
        target: target,
        createdFiles: createdFiles,
        createdDirectories: createdDirectories,
      );

      final inventory = await _inventory(target);
      if (inventory.fileCount != plan.fileCount ||
          inventory.totalBytes != plan.totalBytes) {
        throw StateError('Vault copy verification failed.');
      }

      final validated = await validator.validate(
        expectedProfile: profile,
        directoryPath: target.path,
      );
      return validated;
    } catch (_) {
      await _cleanupCopiedTarget(
        target: target,
        createdFiles: createdFiles,
        createdDirectories: createdDirectories,
        removeRootWhenEmpty: createdRoot,
      );
      rethrow;
    }
  }

  Future<void> _copyDirectoryContents({
    required Directory source,
    required Directory target,
    required List<File> createdFiles,
    required List<Directory> createdDirectories,
  }) async {
    await for (final entity in source.list(
      recursive: false,
      followLinks: false,
    )) {
      final name = entity.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      if (entity is Link) {
        throw FileSystemException(
          'Vault contains an unsupported symbolic link.',
          entity.path,
        );
      }
      if (entity is Directory) {
        final destination = Directory('${target.path}/$name');
        if (await destination.exists()) {
          throw FileSystemException(
            'Vault move target changed during copy.',
            destination.path,
          );
        }
        await destination.create();
        createdDirectories.add(destination);
        await _copyDirectoryContents(
          source: entity,
          target: destination,
          createdFiles: createdFiles,
          createdDirectories: createdDirectories,
        );
        continue;
      }
      if (entity is File) {
        final destination = File('${target.path}/$name');
        if (await destination.exists()) {
          throw FileSystemException(
            'Vault move target changed during copy.',
            destination.path,
          );
        }
        await entity.copy(destination.path);
        createdFiles.add(destination);
      }
    }
  }

  Future<({int fileCount, int totalBytes})> _inventory(
    Directory directory,
  ) async {
    var fileCount = 0;
    var totalBytes = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Link) {
        throw FileSystemException(
          'Vault move target contains an unsupported symbolic link.',
          entity.path,
        );
      }
      if (entity is File) {
        fileCount++;
        totalBytes += await entity.length();
      }
    }
    return (fileCount: fileCount, totalBytes: totalBytes);
  }

  Future<void> _cleanupCopiedTarget({
    required Directory target,
    required List<File> createdFiles,
    required List<Directory> createdDirectories,
    required bool removeRootWhenEmpty,
  }) async {
    for (final file in createdFiles.reversed) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort cleanup must not replace the original copy failure.
      }
    }
    for (final directory in createdDirectories.reversed) {
      try {
        if (await directory.exists() && await directory.list().isEmpty) {
          await directory.delete();
        }
      } catch (_) {
        // Best-effort cleanup must not replace the original copy failure.
      }
    }
    if (removeRootWhenEmpty) {
      try {
        if (await target.exists() && await target.list().isEmpty) {
          await target.delete();
        }
      } catch (_) {
        // Best-effort cleanup must not replace the original copy failure.
      }
    }
  }
}
