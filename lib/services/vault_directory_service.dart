import 'dart:io';

class VaultDirectoryService {
  const VaultDirectoryService();

  Future<void> revealInFinder(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw FileSystemException(
        'Vault directory is unavailable.',
        directoryPath,
      );
    }
    if (!Platform.isMacOS) {
      throw UnsupportedError('Finder reveal is only available on macOS.');
    }

    final result = await Process.run('/usr/bin/open', [directory.path]);
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Could not reveal Vault directory in Finder.',
        directoryPath,
      );
    }
  }
}
