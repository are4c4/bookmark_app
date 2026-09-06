import 'dart:io';

import 'file_managed_resource_resolver.dart';

/// Exports one canonical File Object to an explicit caller-provided path.
///
/// Canonical identity and Vault/profile-relative resolution remain owned by
/// [FileManagedResourceResolver]. This service never rewrites the File Object,
/// moves/deletes its managed source, chooses a destination, or creates another
/// managed-storage root. The destination is created exclusively so export can
/// never overwrite an existing user file.
class CanonicalFileExportService {
  CanonicalFileExportService({required FileManagedResourceResolver resources})
      : _resources = resources;

  final FileManagedResourceResolver _resources;

  Future<void> exportTo({
    required int fileObjectTypeId,
    required int fileObjectId,
    required String destinationPath,
  }) async {
    final destination = destinationPath.trim();
    if (destination.isEmpty) {
      throw const CanonicalFileExportException(
        'ファイルの書き出し先を指定してください。',
      );
    }

    final resource = await _resources.resolveManaged(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );
    if (resource == null) {
      throw const CanonicalFileExportUnavailableException();
    }

    try {
      final destinationType = await FileSystemEntity.type(
        destination,
        followLinks: false,
      );
      if (destinationType != FileSystemEntityType.notFound) {
        throw const CanonicalFileExportException(
          '書き出し先にはすでにファイルまたはフォルダがあります。',
        );
      }
      await _copyExclusively(
        sourcePath: resource.filePath,
        destinationPath: destination,
        expectedSizeBytes: resource.actualSizeBytes,
      );
    } on CanonicalFileExportException {
      rethrow;
    } catch (_) {
      throw const CanonicalFileExportException(
        'ファイルを書き出せませんでした。',
      );
    }
  }

  Future<void> _copyExclusively({
    required String sourcePath,
    required String destinationPath,
    required int expectedSizeBytes,
  }) async {
    RandomAccessFile? source;
    RandomAccessFile? destination;
    var createdDestination = false;
    try {
      source = await File(sourcePath).open(mode: FileMode.read);
      destination = await File(destinationPath).open(
        mode: FileMode.writeOnlyExclusive,
      );
      createdDestination = true;

      var written = 0;
      const chunkSize = 64 * 1024;
      while (true) {
        final bytes = await source.read(chunkSize);
        if (bytes.isEmpty) break;
        await destination.writeFrom(bytes);
        written += bytes.length;
      }
      await destination.flush();
      if (written != expectedSizeBytes) {
        throw const FileSystemException('Export size verification failed.');
      }
    } catch (_) {
      if (createdDestination) {
        try {
          await destination?.close();
        } catch (_) {
          // Best-effort close before removing only the destination we created.
        }
        destination = null;
        try {
          final partial = File(destinationPath);
          if (await partial.exists()) await partial.delete();
        } catch (_) {
          // Preserve the original export failure. Never touch the source file.
        }
      }
      rethrow;
    } finally {
      try {
        await source?.close();
      } catch (_) {
        // Closing after a completed/failed read does not change export result.
      }
      try {
        await destination?.close();
      } catch (_) {
        // Closing after a completed write does not change export result.
      }
    }
  }
}

class CanonicalFileExportUnavailableException implements Exception {
  const CanonicalFileExportUnavailableException();

  @override
  String toString() => '書き出し元のファイルが見つからないか、現在利用できません。';
}

class CanonicalFileExportException implements Exception {
  const CanonicalFileExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
