import 'dart:io';

/// Writes a backup archive through a fresh staging file before replacing the
/// user-selected output path.
///
/// The destination may already be a regular file, symbolic link, or hard link.
/// Writing directly through that path could mutate another inode unexpectedly.
/// Staging first and then replacing only the selected directory entry keeps the
/// archive writer away from every pre-existing destination entity.
class BackupOutputFileService {
  const BackupOutputFileService();

  Future<void> write({
    required String destinationPath,
    required Future<void> Function(String stagedPath) writer,
  }) async {
    final destination = File(destinationPath).absolute;
    final parent = destination.parent;
    if (!await parent.exists()) {
      throw FileSystemException('Backup destination directory is unavailable.');
    }

    final staged = await _createStagedFile(parent);
    try {
      await writer(staged.path);
      await _replaceDestination(staged, destination);
    } catch (_) {
      if (await staged.exists()) {
        await staged.delete();
      }
      rethrow;
    }
  }

  Future<File> _createStagedFile(Directory parent) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final staged = File(
      '${parent.path}/.bookmark-profile-backup-${pid}_$stamp.tmp',
    );
    return staged.create(exclusive: true);
  }

  Future<void> _replaceDestination(File staged, File destination) async {
    final type = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.directory) {
      throw FileSystemException('Backup destination is a directory.');
    }
    if (type == FileSystemEntityType.link) {
      await Link(destination.path).delete();
    } else if (type == FileSystemEntityType.file) {
      await destination.delete();
    } else if (type != FileSystemEntityType.notFound) {
      throw FileSystemException('Backup destination type is unsupported.');
    }

    await staged.rename(destination.path);
  }
}
