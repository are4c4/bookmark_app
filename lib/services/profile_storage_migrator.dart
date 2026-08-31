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

    final rows = await database.customSelect(
      'SELECT id, path FROM photos',
      readsFrom: {database.photos},
    ).get();

    for (final row in rows) {
      final id = row.read<int>('id');
      final sourcePath = row.read<String>('path');
      if (_isInside(sourcePath, targetDir.path)) continue;

      final source = File(sourcePath);
      if (!await source.exists()) continue;

      final fileName = _fileName(sourcePath);
      final targetPath = '${targetDir.path}/${id}_$fileName';
      final target = File(targetPath);
      if (!await target.exists()) {
        await source.copy(targetPath);
      }

      await database.customUpdate(
        'UPDATE photos SET path = ? WHERE id = ?',
        variables: [Variable.withString(targetPath), Variable.withInt(id)],
        updates: {database.photos},
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
