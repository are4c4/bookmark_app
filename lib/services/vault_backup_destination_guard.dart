import 'dart:io';

/// Keeps a complete Vault backup output outside the Vault being archived.
///
/// Backup is a preservation operation. Writing the archive anywhere below the
/// source Vault would mutate the source while it is being recursively read and
/// can make the output archive part of its own input set. Resolve existing
/// filesystem aliases before deciding containment so symlinked paths cannot
/// bypass the boundary.
class VaultBackupDestinationGuard {
  const VaultBackupDestinationGuard();

  Future<String> resolveSafeDestination({
    required String sourceVaultPath,
    required String destinationPath,
  }) async {
    final source = Directory(sourceVaultPath);
    if (!await source.exists()) {
      throw FileSystemException('Source Vault directory is unavailable.');
    }

    final sourceRoot = _normalized(await source.resolveSymbolicLinks());
    final destination = File(destinationPath).absolute;
    final fileName = _fileName(destination.path);
    if (fileName.isEmpty || fileName == '.' || fileName == '..') {
      throw FileSystemException('Backup destination file name is invalid.');
    }

    // Resolve the parent to its real filesystem location and use that resolved
    // path for the eventual write. An outside-looking symlink alias into the
    // Vault is rejected, and later archive staging never needs to traverse the
    // alias again.
    final resolvedParentPath = await destination.parent.resolveSymbolicLinks();
    final resolvedParent = _normalized(resolvedParentPath);
    if (_sameOrInside(resolvedParent, sourceRoot)) {
      _reject();
    }

    final resolvedDestinationPath =
        '${Directory(resolvedParentPath).path}${Platform.pathSeparator}$fileName';
    final resolvedDestination = File(resolvedDestinationPath);
    final type = await FileSystemEntity.type(
      resolvedDestination.path,
      followLinks: false,
    );
    String? targetPath;
    if (type == FileSystemEntityType.link) {
      targetPath = _normalized(
        await Link(resolvedDestination.path).resolveSymbolicLinks(),
      );
    } else if (type == FileSystemEntityType.file) {
      targetPath = _normalized(
        await resolvedDestination.resolveSymbolicLinks(),
      );
    } else if (type == FileSystemEntityType.directory) {
      targetPath = _normalized(
        await Directory(resolvedDestination.path).resolveSymbolicLinks(),
      );
    }

    if (targetPath != null && _sameOrInside(targetPath, sourceRoot)) {
      _reject();
    }
    return resolvedDestination.path;
  }

  Never _reject() {
    throw FileSystemException(
      'Vault backup destination must be outside the source Vault.',
    );
  }

  bool _sameOrInside(String candidate, String root) {
    if (candidate == root) return true;
    final prefix = root == '/' ? '/' : '$root/';
    return candidate.startsWith(prefix);
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index < 0 ? normalized : normalized.substring(index + 1);
  }

  String _normalized(String path) {
    var normalized = path.replaceAll('\\', '/');
    if (normalized != '/') {
      normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    }
    if (Platform.isWindows) {
      normalized = normalized.toLowerCase();
    }
    return normalized;
  }
}
