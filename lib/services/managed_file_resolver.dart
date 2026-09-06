import 'dart:developer' as developer;
import 'dart:io';

import '../data/profile_path_resolver.dart';

/// Read-only file-backed capability shared by primitive ObjectTypes.
///
/// Primitive identity stays in the concrete Object (Image/File/etc.). This
/// resolver owns only portable stored-path resolution plus conservative file
/// existence/metadata probing. It never logs the user path or exception text.
class ManagedFileResolver {
  const ManagedFileResolver({ProfilePathResolver? pathResolver})
      : _pathResolver = pathResolver;

  final ProfilePathResolver? _pathResolver;

  Future<ManagedFileReference?> resolveExisting(String? storedPath) async {
    final normalized = _nonEmpty(storedPath);
    if (normalized == null) return null;
    final resolved = _pathResolver?.resolveStoredPath(normalized) ?? normalized;
    try {
      final stat = await File(resolved).stat();
      if (stat.type != FileSystemEntityType.file) return null;
      return ManagedFileReference(
        storedPath: normalized,
        resolvedPath: resolved,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
      );
    } catch (_, stackTrace) {
      _debugProbeFailure(stackTrace);
      return null;
    }
  }

  String toStoredPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        path,
        'path',
        'Managed file path must not be empty.',
      );
    }
    return _pathResolver?.toStoredPath(normalized) ?? normalized;
  }

  void _debugProbeFailure(StackTrace stackTrace) {
    assert(() {
      developer.log(
        'Managed file probe failed; treating the file-backed capability as unavailable.',
        name: 'bookmark_app.managed_file_resolver',
        stackTrace: stackTrace,
      );
      return true;
    }());
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class ManagedFileReference {
  const ManagedFileReference({
    required this.storedPath,
    required this.resolvedPath,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String storedPath;
  final String resolvedPath;
  final int sizeBytes;
  final DateTime modifiedAt;
}
