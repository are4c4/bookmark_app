import 'dart:io';

import 'package:drift/drift.dart';

import '../data/app_database.dart';

class ProfileStorageMigrator {
  const ProfileStorageMigrator();

  Future<void> migratePhotos({
    required AppDatabase database,
    required String photoDirectoryPath,
  }) async {
    final targetDir = Directory(photoDirectoryPath);
    await targetDir.create(recursive: true);

    final photos = await database.select(database.photos).get();

    for (final photo in photos) {
      if (_isInside(photo.path, targetDir.path)) continue;

      final source = File(photo.path);
      if (!await source.exists()) continue;

      final fileName = _fileName(photo.path);
      final targetPath = '${targetDir.path}/${photo.id}_$fileName';
      final target = File(targetPath);
      if (!await target.exists()) {
        await source.copy(targetPath);
      }

      await (database.update(database.photos)..where((row) => row.id.equals(photo.id))).write(
        PhotosCompanion(path: Value(targetPath)),
      );
    }
  }

  bool _isInside(String path, String directory) {
    final normalizedPath = path.replaceAll('\\', '/');
    final normalizedDirectory = directory.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    return normalizedPath == normalizedDirectory || normalizedPath.startsWith('$normalizedDirectory/');
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index < 0 ? normalized : normalized.substring(index + 1);
  }
}
