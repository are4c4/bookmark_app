import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

class ImportedPhoto {
  const ImportedPhoto({required this.path, required this.originalName});

  final String path;
  final String originalName;
}

class PhotoStorageService {
  const PhotoStorageService({this.photoDirectoryPath});

  final String? photoDirectoryPath;
  static String? activePhotoDirectoryPath;

  static const _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
  };

  Future<List<ImportedPhoto>> importImages() async {
    final sourcePaths = Platform.isMacOS
        ? await _pickImagesOnMacOS()
        : await _pickImagesWithFileSelector();
    return importPaths(sourcePaths);
  }

  Future<List<ImportedPhoto>> importPaths(Iterable<String> sourcePaths) async {
    final paths = sourcePaths.where((path) => _isSupportedImage(path)).toList();
    if (paths.isEmpty) return const [];

    final photoDir = await _resolvePhotoDirectory();
    await photoDir.create(recursive: true);

    final imported = <ImportedPhoto>[];
    var index = 0;
    for (final sourcePath in paths) {
      final source = File(sourcePath);
      if (!await source.exists()) continue;

      final originalName = _fileName(source.path);
      final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final targetPath = '${photoDir.path}/${DateTime.now().microsecondsSinceEpoch}_${index++}_$safeName';
      final target = await source.copy(targetPath);
      imported.add(ImportedPhoto(path: target.path, originalName: originalName));
    }
    return imported;
  }

  Future<Directory> _resolvePhotoDirectory() async {
    final explicit = photoDirectoryPath?.trim();
    if (explicit != null && explicit.isNotEmpty) return Directory(explicit);
    final active = activePhotoDirectoryPath?.trim();
    if (active != null && active.isNotEmpty) return Directory(active);
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/photos');
  }

  Future<List<String>> _pickImagesWithFileSelector() async {
    const imageTypes = XTypeGroup(
      label: '画像',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif'],
    );

    final pickedFiles = await openFiles(acceptedTypeGroups: const [imageTypes]);
    return pickedFiles.map((file) => file.path).toList();
  }

  Future<List<String>> _pickImagesOnMacOS() async {
    const script = r'''
set selectedFiles to choose file with prompt "写真を選択" with multiple selections allowed
set output to ""
repeat with selectedFile in selectedFiles
  set output to output & POSIX path of selectedFile & linefeed
end repeat
return output
''';

    final result = await Process.run('/usr/bin/osascript', const ['-e', script], runInShell: false);

    if (result.exitCode != 0) {
      final error = result.stderr.toString().trim();
      if (error.contains('User canceled') || error.contains('(-128)')) return const [];
      throw StateError(error.isEmpty ? 'macOSのファイル選択画面を開けませんでした (exit ${result.exitCode})' : error);
    }

    return result.stdout
        .toString()
        .split('\n')
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .where((path) => _isSupportedImage(path))
        .toList();
  }

  bool _isSupportedImage(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return false;
    return _allowedExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }
}
