import 'dart:io';

import '../data/profile_path_resolver.dart';
import '../domain/managed_file_ownership.dart';

enum PortableExportFileDisposition {
  managedIncluded,
  externalReference,
}

/// Immutable filesystem plan for one file-like reference in a portable export.
///
/// Logical Object/Property serialization stays outside this Storage contract.
/// A plan only says whether bytes may be included automatically and, if so,
/// which explicitly owned Vault file and package-relative member are safe.
class PortableExportFilePlan {
  const PortableExportFilePlan._({
    required this.disposition,
    required this.referencePath,
    required this.managedSourcePath,
    required this.packageRelativePath,
    required this.ownershipStorageKey,
  });

  const PortableExportFilePlan.managed({
    required String referencePath,
    required String managedSourcePath,
    required String packageRelativePath,
    required String ownershipStorageKey,
  }) : this._(
          disposition: PortableExportFileDisposition.managedIncluded,
          referencePath: referencePath,
          managedSourcePath: managedSourcePath,
          packageRelativePath: packageRelativePath,
          ownershipStorageKey: ownershipStorageKey,
        );

  const PortableExportFilePlan.external({
    required String referencePath,
  }) : this._(
          disposition: PortableExportFileDisposition.externalReference,
          referencePath: referencePath,
          managedSourcePath: null,
          packageRelativePath: null,
          ownershipStorageKey: null,
        );

  final PortableExportFileDisposition disposition;

  /// Persisted/reference form that the logical serializer supplied.
  final String referencePath;

  /// Readable source path only for explicitly owned managed bytes.
  ///
  /// External references deliberately do not expose a byte-copy source through
  /// this plan so callers cannot accidentally turn the default reference-only
  /// export mode into an implicit external-file copy.
  final String? managedSourcePath;

  /// Safe package member only for automatically included managed bytes.
  final String? packageRelativePath;

  /// Explicit Storage provenance retained for managed-byte export metadata.
  final String? ownershipStorageKey;

  bool get includeBytes =>
      disposition == PortableExportFileDisposition.managedIncluded;
}

/// Lexical package path policy shared by portable-export writers.
///
/// This policy intentionally rejects ambiguous input instead of cleaning it up.
/// Archive/directory writers should only receive the validated relative member.
class PortableExportPackagePathPolicy {
  const PortableExportPackagePathPolicy();

  String validateRelativePath(String path) {
    if (path.isEmpty) {
      throw ArgumentError.value(
        path,
        'path',
        'Portable export package path must not be empty.',
      );
    }
    if (path.contains('\u0000')) {
      throw StateError('Portable export package path contains a NUL byte.');
    }
    if (path.contains('\\')) {
      throw StateError(
        'Portable export package path must use unambiguous forward slashes.',
      );
    }
    if (_isAbsoluteOrDriveQualified(path)) {
      throw StateError('Portable export package path must be relative.');
    }

    final segments = path.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw StateError(
        'Portable export package path contains an unsafe path segment.',
      );
    }
    return path;
  }

  /// Resolves a validated package member below [packageRootPath].
  ///
  /// The package root does not need to exist yet; this method performs no write.
  String resolve({
    required String packageRootPath,
    required String packageRelativePath,
  }) {
    final rootValue = packageRootPath.trim();
    if (rootValue.isEmpty) {
      throw ArgumentError.value(
        packageRootPath,
        'packageRootPath',
        'Portable export package root must not be empty.',
      );
    }

    final relative = validateRelativePath(packageRelativePath);
    final root = _normalizedAbsolute(rootValue);
    final separator = root.endsWith('/') ? '' : '/';
    final resolved = _normalizedAbsolute('$root$separator$relative');
    final prefix = root.endsWith('/') ? root : '$root/';
    if (!resolved.startsWith(prefix)) {
      throw StateError('Portable export package member escaped package root.');
    }
    return resolved;
  }

  bool _isAbsoluteOrDriveQualified(String path) =>
      path.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(path);

  String _normalizedAbsolute(String path) {
    final normalized = Directory(path).absolute.path.replaceAll('\\', '/');
    if (normalized == '/' || RegExp(r'^[A-Za-z]:/$').hasMatch(normalized)) {
      return normalized;
    }
    return normalized.replaceAll(RegExp(r'/+$'), '');
  }
}

/// Plans portable-export handling for persisted file references without mutating
/// the source Vault.
///
/// Only `vault-managed-copy-v1` grants automatic byte inclusion. Path location
/// alone is never treated as ownership. Unowned absolute paths remain external
/// references by default; unowned relative paths fail closed because Storage
/// cannot safely infer whether they are managed, legacy or malformed.
class PortableExportFilePlanner {
  const PortableExportFilePlanner({
    this.packagePaths = const PortableExportPackagePathPolicy(),
  });

  final PortableExportPackagePathPolicy packagePaths;

  Future<PortableExportFilePlan> plan({
    required String storedPath,
    required String? ownershipStorageKey,
    String? vaultDirectoryPath,
  }) async {
    if (storedPath.trim().isEmpty) {
      throw ArgumentError.value(
        storedPath,
        'storedPath',
        'Portable export file reference must not be empty.',
      );
    }

    final ownership = ownershipStorageKey?.trim();
    if (ownership != null && ownership.isNotEmpty) {
      if (ownership != ManagedFileOwnership.vaultManagedCopy.storageKey) {
        throw StateError(
          'Portable export does not recognize this managed-file ownership.',
        );
      }
      return _planManaged(
        storedPath: storedPath,
        vaultDirectoryPath: vaultDirectoryPath,
        ownershipStorageKey: ownership,
      );
    }

    if (_isExternalAbsolutePath(storedPath)) {
      return PortableExportFilePlan.external(referencePath: storedPath);
    }

    throw StateError(
      'Vault-relative export references require explicit managed-file ownership.',
    );
  }

  Future<PortableExportFilePlan> _planManaged({
    required String storedPath,
    required String? vaultDirectoryPath,
    required String ownershipStorageKey,
  }) async {
    final vaultValue = vaultDirectoryPath?.trim();
    if (vaultValue == null || vaultValue.isEmpty) {
      throw ArgumentError.value(
        vaultDirectoryPath,
        'vaultDirectoryPath',
        'Managed-byte export requires an active Vault directory.',
      );
    }

    final safeStoredPath = packagePaths.validateRelativePath(storedPath);
    final segments = safeStoredPath.split('/');
    if (segments.length < 2 || segments.first != 'attachments') {
      throw StateError(
        'Managed-byte export is outside the Vault attachments boundary.',
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
    if (attachmentsType != FileSystemEntityType.directory) {
      throw FileSystemException('Vault attachments directory is unavailable.');
    }

    await _validateManagedParents(
      attachmentsPath: attachments.path,
      relativeSegments: segments,
    );

    final resolvedPath = ProfilePathResolver(vault.path)
        .resolveStoredPath(safeStoredPath);
    if (!_isInsideAttachments(
      resolvedPath: resolvedPath,
      vaultDirectoryPath: vault.path,
    )) {
      throw StateError('Managed-byte export source escaped the Vault.');
    }

    final sourceType = await FileSystemEntity.type(
      resolvedPath,
      followLinks: false,
    );
    if (sourceType != FileSystemEntityType.file) {
      throw FileSystemException(
        'Managed-byte export requires a regular non-symlink source file.',
      );
    }

    return PortableExportFilePlan.managed(
      referencePath: safeStoredPath,
      managedSourcePath: File(resolvedPath).absolute.path,
      packageRelativePath: safeStoredPath,
      ownershipStorageKey: ownershipStorageKey,
    );
  }

  Future<void> _validateManagedParents({
    required String attachmentsPath,
    required List<String> relativeSegments,
  }) async {
    var current = attachmentsPath;
    for (var index = 1; index < relativeSegments.length - 1; index++) {
      current = '$current/${relativeSegments[index]}';
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type != FileSystemEntityType.directory) {
        throw FileSystemException(
          'Managed-byte export parent directory is unavailable.',
        );
      }
    }
  }

  bool _isInsideAttachments({
    required String resolvedPath,
    required String vaultDirectoryPath,
  }) {
    final target = _normalizedAbsolute(resolvedPath);
    final attachments = _normalizedAbsolute(
      '$vaultDirectoryPath/attachments',
    );
    return target.startsWith('$attachments/');
  }

  bool _isExternalAbsolutePath(String path) =>
      path.startsWith('/') ||
      path.startsWith('\\\\') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

  String _normalizedAbsolute(String path) {
    final normalized = File(path).absolute.path.replaceAll('\\', '/');
    if (normalized == '/' || RegExp(r'^[A-Za-z]:/$').hasMatch(normalized)) {
      return normalized;
    }
    return normalized.replaceAll(RegExp(r'/+$'), '');
  }
}
