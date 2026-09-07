class ProfilePathResolver {
  const ProfilePathResolver(this.profileDirectoryPath);

  final String? profileDirectoryPath;

  String resolveStoredPath(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) {
      return path;
    }
    final root = _normalizedRoot;
    if (root == null || root.isEmpty) return path;
    return '$root/${path.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '')}';
  }

  /// Converts either an absolute managed path or an already-stored relative
  /// path to one canonical portable stored-path identity.
  ///
  /// External absolute paths remain absolute. Relative paths are first resolved
  /// against the active profile/Vault and then converted back to stored form so
  /// absolute and relative representations of the same managed resource
  /// converge on one identity.
  String canonicalStoredPath(String path) {
    final candidate = path.trim();
    if (candidate.isEmpty) {
      throw ArgumentError.value(
        path,
        'path',
        'Stored path must not be empty.',
      );
    }
    return toStoredPath(resolveStoredPath(candidate));
  }

  String toStoredPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final root = _normalizedRoot;
    if (root == null || root.isEmpty) return normalized;
    if (normalized == root) return '.';
    final prefix = '$root/';
    return normalized.startsWith(prefix)
        ? normalized.substring(prefix.length)
        : normalized;
  }

  String? get _normalizedRoot => profileDirectoryPath
      ?.replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '');
}
