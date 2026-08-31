import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImportedPhoto {
  const ImportedPhoto({required this.path, required this.originalName});

  final String path;
  final String originalName;
}

class PhotoStorageService {
  const PhotoStorageService();

  Future<List<ImportedPhoto>> importImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return const [];

    final support = await getApplicationSupportDirectory();
    final photoDir = Directory('${support.path}/photos');
    await photoDir.create(recursive: true);

    final imported = <ImportedPhoto>[];
    var index = 0;
    for (final picked in result.files) {
      final sourcePath = picked.path;
      if (sourcePath == null) continue;
      final source = File(sourcePath);
      final extension = picked.extension == null ? '' : '.${picked.extension}';
      final base = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final targetPath = '${photoDir.path}/${DateTime.now().microsecondsSinceEpoch}_${index++}_$base';
      final target = await source.copy(targetPath.endsWith(extension) || extension.isEmpty ? targetPath : '$targetPath$extension');
      imported.add(ImportedPhoto(path: target.path, originalName: picked.name));
    }
    return imported;
  }
}
