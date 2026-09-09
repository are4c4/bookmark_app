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

  Future<void> validate({
    required String sourceVaultPath,
    required String destinationPath,
  }) async {
    final source = Directory(sourceVaultPath);
    if (!await source.exists()) {
      throw FileSystemException('Source Vault directory is unavailable.');
    }

    final sourceRoot = _normalized(await source.resolveSymbolicLinks());
    final destination = File(destinationPath).absolute;

    // A save picker normally returns a path in an existing directory. Resolve
    // that parent first so an outside-looking symlink alias into the Vault is
    // rejected even when the destination file does not exist yet.
    final resolvedParent =
        _normalized(await destination.parent.resolveSymbolicLinks());
    if (_sameOrInside(resolvedParent, sourceRoot)) {
      _reject();
    }

    // If the selected destination already exists, resolve that entity as well.
    // This specifically closes an existing file-symlink outside the Vault that
    // redirects writes back into the source tree.
    final type = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    String? resolvedDestination;
    if (type == FileSystemEntityType.link) {
      resolvedDestination =
          _normalized(await Link(destination.path).resolveSymbolicLinks());
    } else if (type == FileSystemEntityType.file) {
      resolvedDestination =
          _normalized(await File(destination.path).resolveSymbolicLinks());
    } else if (type == FileSystemEntityType.directory) {
      resolvedDestination =
          _normalized(await Directory(destination.path).resolveSymbolicLinks());
    }

    if (resolvedDestination != null &&
        _sameOrInside(resolvedDestination, sourceRoot)) {
      _reject();
    }
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
