/// Persistable proof that the application owns a managed file's physical bytes.
///
/// Ownership is separate from path location: a file living under the Vault is
/// not deletable merely because of its path. Values are intentionally closed so
/// primitive code cannot manufacture delete authority from arbitrary strings.
enum ManagedFileOwnership {
  vaultManagedCopy('vault-managed-copy-v1');

  const ManagedFileOwnership(this.storageKey);

  /// Stable storage representation shared with the Vault filesystem boundary.
  final String storageKey;

  static ManagedFileOwnership? fromStorageKey(String? value) {
    final candidate = value?.trim();
    if (candidate == null || candidate.isEmpty) return null;
    for (final ownership in values) {
      if (ownership.storageKey == candidate) return ownership;
    }
    return null;
  }
}
