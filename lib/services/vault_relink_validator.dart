import 'dart:convert';
import 'dart:io';

import 'profile_manager.dart';

class VaultRelinkValidator {
  const VaultRelinkValidator();

  static const _sqliteHeader = 'SQLite format 3\u0000';

  Future<DatabaseProfile> validate({
    required DatabaseProfile expectedProfile,
    required String directoryPath,
  }) async {
    final trimmedPath = directoryPath.trim();
    if (trimmedPath.isEmpty) {
      throw ArgumentError('Vault directory is empty');
    }

    final directory = Directory(trimmedPath);
    if (!await directory.exists()) {
      throw FileSystemException('Vault directory is unavailable.', trimmedPath);
    }

    final metadataFile = File('${directory.path}/profile.json');
    if (!await metadataFile.exists()) {
      throw FileSystemException(
        'Vault metadata is unavailable.',
        metadataFile.path,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(await metadataFile.readAsString());
    } on FormatException {
      throw const FormatException('Vault metadata is invalid.');
    }
    if (decoded is! Map) {
      throw const FormatException('Vault metadata is invalid.');
    }
    final metadata = Map<String, Object?>.from(decoded);
    if (metadata['id'] != expectedProfile.id ||
        metadata['database'] != 'database.sqlite') {
      throw const FormatException(
        'Selected folder does not match the registered Vault.',
      );
    }

    final databaseFile = File('${directory.path}/database.sqlite');
    if (!await databaseFile.exists()) {
      throw FileSystemException(
        'Vault database is unavailable.',
        databaseFile.path,
      );
    }

    final handle = await databaseFile.open(mode: FileMode.read);
    try {
      final header = await handle.read(_sqliteHeader.length);
      if (String.fromCharCodes(header) != _sqliteHeader) {
        throw const FormatException('Vault database is invalid.');
      }
    } finally {
      await handle.close();
    }

    return expectedProfile.copyWith(directoryPath: directory.path);
  }
}
