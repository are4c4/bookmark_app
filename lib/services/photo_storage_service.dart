import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import '../data/profile_path_resolver.dart';

class ImportedPhoto {
  const ImportedPhoto({
    required this.path,
    required this.originalName,
    this.contentType,
    this.createdNew = true,
  });

  final String path;
  final String originalName;
  final String? contentType;

  /// Whether this import call created [path].
  ///
  /// Canonical Image import may reuse an existing byte-identical managed file.
  /// Callers performing rollback cleanup must never delete that pre-existing
  /// shared file when a later Object operation fails.
  final bool createdNew;
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
  static const _extensionByContentType = <String, String>{
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
    'image/heic': 'heic',
    'image/heif': 'heif',
  };

  Future<List<ImportedPhoto>> importImages({
    bool reuseIdentical = false,
  }) async {
    final sourcePaths = Platform.isMacOS
        ? await _pickImagesOnMacOS()
        : await _pickImagesWithFileSelector();
    return importPaths(sourcePaths, reuseIdentical: reuseIdentical);
  }

  Future<List<ImportedPhoto>> importPaths(
    Iterable<String> sourcePaths, {
    bool reuseIdentical = false,
  }) async {
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
      final contentType = _contentTypeForName(originalName);
      if (reuseIdentical) {
        final existing = await _findIdenticalManagedFile(photoDir, source);
        if (existing != null) {
          imported.add(
            ImportedPhoto(
              path: existing.path,
              originalName: originalName,
              contentType: contentType,
              createdNew: false,
            ),
          );
          continue;
        }
      }

      final targetPath = _nextManagedPath(photoDir, originalName, index++);
      final target = await source.copy(targetPath);
      imported.add(
        ImportedPhoto(
          path: target.path,
          originalName: originalName,
          contentType: contentType,
        ),
      );
    }
    return imported;
  }

  /// Imports one source already classified as a supported Image by content/MIME.
  ///
  /// The source filename is preserved as provenance even when its extension is
  /// misleading. The managed copy receives an extension derived from the
  /// canonical Image content type so downstream image codecs/editors never
  /// depend on the untrusted source extension.
  Future<ImportedPhoto?> importClassifiedImagePath({
    required String sourcePath,
    required String contentType,
    bool reuseIdentical = false,
  }) async {
    final normalizedContentType = contentType.trim().toLowerCase();
    final managedExtension = _extensionByContentType[normalizedContentType];
    if (managedExtension == null) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'Unsupported managed Image content type.',
      );
    }

    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final stat = await source.stat();
    if (stat.type != FileSystemEntityType.file) return null;

    final photoDir = await _resolvePhotoDirectory();
    await photoDir.create(recursive: true);
    final originalName = _fileName(source.path);
    if (reuseIdentical) {
      final existing = await _findIdenticalManagedFile(photoDir, source);
      if (existing != null) {
        return ImportedPhoto(
          path: existing.path,
          originalName: originalName,
          contentType: normalizedContentType,
          createdNew: false,
        );
      }
    }

    final managedName = _managedImageName(originalName, managedExtension);
    final target = await source.copy(_nextManagedPath(photoDir, managedName, 0));
    return ImportedPhoto(
      path: target.path,
      originalName: originalName,
      contentType: normalizedContentType,
    );
  }

  /// Persists already-downloaded image bytes into the same app-managed photo
  /// directory used by local imports.
  Future<ImportedPhoto> importBytes({
    required List<int> bytes,
    required String originalName,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Image bytes must not be empty.');
    }
    final name = _fileName(originalName.trim());
    if (name.isEmpty || !_isSupportedImage(name)) {
      throw ArgumentError.value(
        originalName,
        'originalName',
        'Managed image name must have a supported image extension.',
      );
    }
    final photoDir = await _resolvePhotoDirectory();
    await photoDir.create(recursive: true);
    final target = File(_nextManagedPath(photoDir, name, 0));
    await target.writeAsBytes(bytes, flush: true);
    return ImportedPhoto(
      path: target.path,
      originalName: name,
      contentType: _contentTypeForName(name),
    );
  }

  /// Deletes a legacy Photo file only when the configured active managed-photo
  /// root proves physical ownership of the target.
  ///
  /// This method intentionally fails closed. External absolute paths, relative
  /// paths that resolve outside the active profile/Vault `photos/` directory,
  /// traversal, symlinks, non-file entities and unavailable roots are preserved.
  /// A missing managed file is idempotent and never causes the root to be
  /// recreated. The optional edit backup is removed only when it independently
  /// resolves to a regular file inside the same managed root.
  Future<void> deleteManagedPhoto(String path) async {
    final photoDir = _configuredPhotoDirectory();
    if (photoDir == null) return;

    final root = photoDir.absolute;
    final rootType = await FileSystemEntity.type(
      root.path,
      followLinks: false,
    );
    if (rootType != FileSystemEntityType.directory) return;

    final candidate = path.trim();
    if (candidate.isEmpty || _hasUnsafePathSegments(candidate)) return;

    final profileRoot = _parentDirectoryPath(root.path);
    if (profileRoot == null) return;
    final resolvedPath =
        ProfilePathResolver(profileRoot).resolveStoredPath(candidate);
    if (!_isAbsolutePath(resolvedPath) ||
        !_isWithinRoot(resolvedPath, root.path)) {
      return;
    }

    final type = await FileSystemEntity.type(
      resolvedPath,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) return;

    final canonicalRoot = await root.resolveSymbolicLinks();
    final canonicalTarget = await File(resolvedPath).resolveSymbolicLinks();
    if (!_isWithinRoot(canonicalTarget, canonicalRoot)) return;

    final originalBackup = File('$resolvedPath.bookmark_original');
    final deleteBackup = await _isSafeManagedBackup(
      originalBackup,
      rootPath: root.path,
      canonicalRootPath: canonicalRoot,
    );

    await File(resolvedPath).delete();
    if (deleteBackup) {
      await originalBackup.delete();
    }
  }

  Directory? _configuredPhotoDirectory() {
    final explicit = photoDirectoryPath?.trim();
    if (explicit != null && explicit.isNotEmpty) return Directory(explicit);
    final active = activePhotoDirectoryPath?.trim();
    if (active != null && active.isNotEmpty) return Directory(active);
    return null;
  }

  Future<bool> _isSafeManagedBackup(
    File backup, {
    required String rootPath,
    required String canonicalRootPath,
  }) async {
    if (!_isWithinRoot(backup.path, rootPath)) return false;
    final type = await FileSystemEntity.type(
      backup.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.file) return false;
    final canonicalBackup = await backup.resolveSymbolicLinks();
    return _isWithinRoot(canonicalBackup, canonicalRootPath);
  }

  bool _hasUnsafePathSegments(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized
        .split('/')
        .any((segment) => segment == '.' || segment == '..');
  }

  String? _parentDirectoryPath(String path) {
    final normalized = path
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    final slash = normalized.lastIndexOf('/');
    if (slash <= 0) return null;
    return normalized.substring(0, slash);
  }

  bool _isWithinRoot(String candidate, String root) {
    final normalizedCandidate = _normalizedAbsolutePath(candidate);
    final normalizedRoot = _normalizedAbsolutePath(root);
    return normalizedCandidate.startsWith('$normalizedRoot/');
  }

  String _normalizedAbsolutePath(String path) => File(path)
      .absolute
      .path
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '');

  bool _isAbsolutePath(String path) =>
      path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

  Future<Directory> _resolvePhotoDirectory() async {
    final explicit = photoDirectoryPath?.trim();
    if (explicit != null && explicit.isNotEmpty) return Directory(explicit);
    final active = activePhotoDirectoryPath?.trim();
    if (active != null && active.isNotEmpty) return Directory(active);
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/photos');
  }

  Future<File?> _findIdenticalManagedFile(
    Directory directory,
    File source,
  ) async {
    final entries = await directory.list(followLinks: false).toList();
    final candidates = entries
        .whereType<File>()
        .where((file) => _isSupportedImage(file.path))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));
    final sourcePath = source.absolute.path;
    for (final candidate in candidates) {
      if (candidate.absolute.path == sourcePath) return candidate;
      if (await _sameFileContent(source, candidate)) return candidate;
    }
    return null;
  }

  Future<bool> _sameFileContent(File left, File right) async {
    RandomAccessFile? leftHandle;
    RandomAccessFile? rightHandle;
    try {
      if (await left.length() != await right.length()) return false;
      leftHandle = await left.open();
      rightHandle = await right.open();
      const chunkSize = 64 * 1024;
      while (true) {
        final leftBytes = await leftHandle.read(chunkSize);
        final rightBytes = await rightHandle.read(chunkSize);
        if (leftBytes.length != rightBytes.length) return false;
        if (leftBytes.isEmpty) return true;
        for (var index = 0; index < leftBytes.length; index++) {
          if (leftBytes[index] != rightBytes[index]) return false;
        }
      }
    } on FileSystemException {
      // A candidate may disappear while scanning. Treat it as a cache miss and
      // continue with a normal managed copy rather than failing the import.
      return false;
    } finally {
      if (leftHandle != null) await leftHandle.close();
      if (rightHandle != null) await rightHandle.close();
    }
  }

  String _nextManagedPath(Directory directory, String originalName, int index) {
    final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '${directory.path}/${DateTime.now().microsecondsSinceEpoch}_${index}_$safeName';
  }

  String _managedImageName(String originalName, String managedExtension) {
    final name = _fileName(originalName);
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final safeStem = stem.trim().isEmpty ? 'image' : stem;
    return '$safeStem.$managedExtension';
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

    final result = await Process.run(
      '/usr/bin/osascript',
      const ['-e', script],
      runInShell: false,
    );

    if (result.exitCode != 0) {
      final error = result.stderr.toString().trim();
      if (error.contains('User canceled') || error.contains('(-128)')) {
        return const [];
      }
      throw StateError(
        error.isEmpty
            ? 'macOSのファイル選択画面を開けませんでした (exit ${result.exitCode})'
            : error,
      );
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

  String? _contentTypeForName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return null;
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }
}
