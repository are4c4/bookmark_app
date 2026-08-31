import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

class ImportedPhoto {
  const ImportedPhoto({required this.path, required this.originalName});

  final String path;
  final String originalName;
}

class PhotoStorageService {
  const PhotoStorageService();

  Future<List<ImportedPhoto>> importImages() async {
    const imageTypes = XTypeGroup(
      label: '画像',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif'],
    );

    final pickedFiles = await openFiles(
      acceptedTypeGroups: const [imageTypes],
    );
    if (pickedFiles.isEmpty) return const [];

    final support = await getApplicationSupportDirectory();
    final photoDir = Directory('${support.path}/photos');
    await photoDir.create(recursive: true);

    final imported = <ImportedPhoto>[];
    var index = 0;
    for (final picked in pickedFiles) {
      final source = File(picked.path);
      if (!await source.exists()) continue;

      final originalName = picked.name;
      final safeName = originalName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final targetPath =
          '${photoDir.path}/${DateTime.now().microsecondsSinceEpoch}_${index++}_$safeName';
      final target = await source.copy(targetPath);
      imported.add(
        ImportedPhoto(path: target.path, originalName: originalName),
      );
    }
    return imported;
  }
}
