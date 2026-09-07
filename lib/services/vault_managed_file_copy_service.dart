import 'dart:developer' as developer;
import 'dart:io';

import '../data/profile_path_resolver.dart';

/// Explicit filesystem ownership granted only for bytes copied by
/// [VaultManagedFileCopyService].
///
/// A path being located under a Vault is not, by itself, proof that the app may
/// delete it. Callers should retain this grant alongside any downstream
/// identity that needs to distinguish app-copied bytes from external files.
enum VaultManagedFileOwnership {
  vaultManagedCopy('vault-managed-copy-v1');

  const VaultManagedFileOwnership(this.storageKey);

  /// Stable value that a downstream identity layer may persist without
  /// re-deriving ownership from the filesystem path.
  final String storageKey;
}

enum VaultManagedFileDeleteResult {
  deleted,
  alreadyMissing,
}

/// Opaque receipt for one successful managed copy.
///
/// The private constructor prevents callers from manufacturing ownership for an
/// arbitrary existing path. Primitive Object identity remains outside this
/// storage-layer contract.
class VaultManagedFileCopy {
  const VaultManagedFileCopy._({
    required this.storedPath,
    required this.resolvedPath,
    required this.vaultDirectoryPath,
    required this.originalFilename,
    required this.sizeBytes,
  });

  final String storedPath;
  final String resolvedPath;
  final String vaultDirectoryPath;
  final String originalFilename;
  final int sizeBytes;

  VaultManagedFileOwnership get ownership =>
      VaultManagedFileOwnership.vaultManagedCopy;
}

/// Owns managed regular-file placement inside a Vault's `attachments/` area.
///
/// This service owns only filesystem placement, portable path conversion,
/// explicit filesystem ownership, rollback and ownership-gated physical delete.
/// MIME classification, File/Image Object identity, metadata and Relation
/// behavior belong to their feature lanes.
class VaultManagedFileCopyService {
  VaultManagedFileCopyService();

  int _sequence = 0;

  Future<VaultManagedFileCopy> copyIntoVault({
    required String sourcePath,
    required String vaultDirectoryPath,
  }) async {
    final sourceValue = sourcePath.trim();
    final vaultValue = vaultDirectoryPath.trim();
    if (sourceValue.isEmpty) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'Managed file source path must not be empty.',
      );
    }
    if (vaultValue.isEmpty) {
      throw ArgumentError.value(
        vaultDirectoryPath,
        'vaultDirectoryPath',
        'Vault directory path must not be empty.',
      );
    }

    final source = File(sourceValue);
    final sourceType =
        await FileSystemEntity.type(source.path, followLinks: false);
    if (sourceType != FileSystemEntityType.file) {
      throw FileSystemException(
        'Managed file import requires a regular source file.',
      );
    }

    final vault = Directory(vaultValue).absolute;
    if (!await vault.exists()) {
      throw FileSystemException('Vault directory is unavailable.');
    }

    final attachments = Directory('${vault.path}/attachments');
    final attachmentsType = await FileSystemEntity.type(
      attachments.path,
      followLinks: false,
    );
    if (attachmentsType == FileSystemEntityType.notFound) {
      await attachments.create();
    } else if (attachmentsType != FileSystemEntityType.directory) {
      throw FileSystemException('Vault attachments directory is unavailable.');
    }

    final originalFilename = _fileName(source.path);
    final safeFilename = _safeFilename(originalFilename);
    final target = await _availableTarget(attachments, safeFilename);

    var copied = false;
    try {
      final copiedFile = await source.copy(target.path);
      copied = true;
      final stat = await copiedFile.stat();
      if (stat.type != FileSystemEntityType.file) {
        throw FileSystemException('Managed file copy did not create a file.');
      }

      final resolvedPath = copiedFile.absolute.path;
      final storedPath =
          ProfilePathResolver(vault.path).canonicalStoredPath(resolvedPath);
      if (!_isManagedAttachmentPath(
        resolvedPath: resolvedPath,
        vaultDirectoryPath: vault.path,
      )) {
        throw StateError('Managed file copy escaped the Vault attachments area.');
      }
      if (_isAbsolute(storedPath)) {
        throw StateError('Managed file copy did not produce a portable path.');
      }

      return VaultManagedFileCopy._(
        storedPath: storedPath,
        resolvedPath: resolvedPath,
        vaultDirectoryPath: vault.path,
        originalFilename: originalFilename,
        sizeBytes: stat.size,
      );
    } catch (error, stackTrace) {
      if (copied) {
        await _cleanupFailedCopy(target);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Deletes persisted managed bytes only when explicit Storage ownership and a
  /// safe Vault-relative `attachments/...` path are both supplied.
  ///
  /// This is intentionally stricter than checking whether an arbitrary path
  /// happens to live under the Vault. External absolute paths, traversal,
  /// symlinks and non-file entities fail closed. A missing managed file is
  /// treated as an idempotent successful outcome without creating directories.
  Future<VaultManagedFileDeleteResult> deleteOwnedCopy({
    required String storedPath,
    required String vaultDirectoryPath,
    required String ownershipStorageKey,
  }) async {
    if (ownershipStorageKey !=
        VaultManagedFileOwnership.vaultManagedCopy.storageKey) {
      throw StateError('Managed file ownership is not recognized.');
    }

    final vaultValue = vaultDirectoryPath.trim();
    if (vaultValue.isEmpty) {
      throw ArgumentError.value(
        vaultDirectoryPath,
        'vaultDirectoryPath',
        'Vault directory path must not be empty.',
      );
    }
    final vault = Directory(vaultValue).absolute;
    if (!await vault.exists()) {
      throw FileSystemException('Vault directory is unavailable.');
    }

    final candidate = _validatedManagedStoredPath(storedPath);
    final resolvedPath =
        ProfilePathResolver(vault.path).resolveStoredPath(candidate);
    if (!_isManagedAttachmentPath(
      resolvedPath: resolvedPath,
      vaultDirectoryPath: vault.path,
    )) {
      throw StateError('Managed file delete target is outside the Vault.');
    }

    final type = await FileSystemEntity.type(
      resolvedPath,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      return VaultManagedFileDeleteResult.alreadyMissing;
    }
    if (type != FileSystemEntityType.file) {
      throw StateError('Managed file delete target is not a regular file.');
    }
    await File(resolvedPath).delete();
    return VaultManagedFileDeleteResult.deleted;
  }

  /// Rolls back only a copy represented by a receipt created by this library.
  Future<void> rollbackCopy(VaultManagedFileCopy copy) async {
    final expected = ProfilePathResolver(copy.vaultDirectoryPath)
        .resolveStoredPath(copy.storedPath);
    if (!_samePath(expected, copy.resolvedPath)) {
      throw StateError('Managed file rollback receipt is inconsistent.');
    }
    await deleteOwnedCopy(
      storedPath: copy.storedPath,
      vaultDirectoryPath: copy.vaultDirectoryPath,
      ownershipStorageKey: copy.ownership.storageKey,
    );
  }

  Future<File> _availableTarget(
    Directory attachments,
    String safeFilename,
  ) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final sequence = _sequence++;
    var attempt = 0;
    while (true) {
      final suffix = attempt == 0 ? '' : '_$attempt';
      final candidate = File(
        '${attachments.path}/${stamp}_${sequence}${suffix}_$safeFilename',
      );
      final type = await FileSystemEntity.type(
        candidate.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) return candidate;
      attempt++;
    }
  }

  Future<void> _cleanupFailedCopy(File target) async {
    try {
      final type = await FileSystemEntity.type(target.path, followLinks: false);
      if (type == FileSystemEntityType.file) {
        await target.delete();
      }
    } catch (_, stackTrace) {
      assert(() {
        developer.log(
          'Managed file copy cleanup failed.',
          name: 'bookmark_app.vault_managed_file_copy',
          stackTrace: stackTrace,
        );
        return true;
      }());
    }
  }

  String _validatedManagedStoredPath(String storedPath) {
    final candidate = storedPath.trim().replaceAll('\\', '/');
    if (candidate.isEmpty || _isAbsolute(candidate)) {
      throw StateError('Managed file path must be Vault-relative.');
    }
    final segments = candidate.split('/');
    if (segments.length < 2 ||
        segments.first != 'attachments' ||
        segments.any((segment) =>
            segment.isEmpty || segment == '.' || segment == '..')) {
      throw StateError('Managed file path is outside the attachments boundary.');
    }
    return candidate;
  }

  bool _isManagedAttachmentPath({
    required String resolvedPath,
    required String vaultDirectoryPath,
  }) {
    final target = _normalizedAbsolute(resolvedPath);
    final attachments = _normalizedAbsolute(
      '$vaultDirectoryPath/attachments',
    );
    return target.startsWith('$attachments/');
  }

  bool _samePath(String left, String right) =>
      _normalizedAbsolute(left) == _normalizedAbsolute(right);

  String _normalizedAbsolute(String path) => File(path)
      .absolute
      .path
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '');

  bool _isAbsolute(String path) =>
      path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

  String _safeFilename(String filename) {
    final safe = filename.replaceAll(
      RegExp(r'[^A-Za-z0-9._\-ぁ-んァ-ヶ一-龠々ー ]'),
      '_',
    );
    if (safe.isEmpty || safe == '.' || safe == '..') return 'file';
    return safe;
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }
}
