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
