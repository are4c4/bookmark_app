import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'profile_manager.dart';
import 'vault_relink_validator.dart';

class VaultRegistryRecoveryService {
  const VaultRegistryRecoveryService({
    this.applicationSupportDirectoryProvider,
    this.validator = const VaultRelinkValidator(),
  });

  final Future<Directory> Function()? applicationSupportDirectoryProvider;
  final VaultRelinkValidator validator;

  Future<DatabaseProfile> relink({
    required String profileId,
    required String directoryPath,
  }) async {
    final trimmedId = profileId.trim();
    if (trimmedId.isEmpty) throw ArgumentError('Vault id is empty');

    final support = await (applicationSupportDirectoryProvider ??
        getApplicationSupportDirectory)();
    final registry = File('${support.path}/bookmark_profiles.json');
    if (!await registry.exists()) {
      throw FileSystemException('Vault registry is unavailable.', registry.path);
    }

    final original = await registry.readAsString();
    final Object? decoded;
    try {
      decoded = jsonDecode(original);
    } on FormatException {
      throw const FormatException('Vault registry is invalid.');
    }
    if (decoded is! Map) {
      throw const FormatException('Vault registry is invalid.');
    }

    final root = Map<String, Object?>.from(decoded);
    final rawProfiles = root['profiles'];
    if (rawProfiles is! List) {
      throw const FormatException('Vault registry is invalid.');
    }

    Map<String, Object?>? registered;
    for (final raw in rawProfiles) {
      if (raw is! Map) continue;
      final profile = Map<String, Object?>.from(raw);
      if (profile['id'] == trimmedId) {
        registered = profile;
        break;
      }
    }
    if (registered == null) {
      throw StateError('The requested Vault is not registered.');
    }

    final name = registered['name'];
    final databaseName = registered['databaseName'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Vault registry is invalid.');
    }

    final expected = DatabaseProfile(
      id: trimmedId,
      name: name.trim(),
      databaseName: databaseName is String && databaseName.trim().isNotEmpty
          ? databaseName
          : 'BookmarkApp/Profiles/$trimmedId/database',
      directoryPath: (registered['directoryPath'] as String?) ?? '',
    );

    final validated = await validator.validate(
      expectedProfile: expected,
      directoryPath: directoryPath,
    );

    final validatedAbsolute = Directory(validated.directoryPath).absolute.path;
    for (final raw in rawProfiles) {
      if (raw is! Map) continue;
      final candidate = Map<String, Object?>.from(raw);
      if (candidate['id'] == trimmedId) continue;
      final otherPath = candidate['directoryPath'];
      if (otherPath is String &&
          otherPath.trim().isNotEmpty &&
          Directory(otherPath).absolute.path == validatedAbsolute) {
        throw StateError('The selected folder is already registered as another Vault.');
      }
    }

    root['profiles'] = rawProfiles.map<Object?>((raw) {
      if (raw is! Map) return raw;
      final profile = Map<String, Object?>.from(raw);
      if (profile['id'] != trimmedId) return profile;
      return <String, Object?>{
        ...profile,
        'directoryPath': validated.directoryPath,
      };
    }).toList();

    final replacement = const JsonEncoder.withIndent('  ').convert(root);
    await _replaceRegistryAtomically(
      registry: registry,
      original: original,
      replacement: replacement,
    );
    return validated;
  }

  Future<void> _replaceRegistryAtomically({
    required File registry,
    required String original,
    required String replacement,
  }) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${registry.path}.relink-$stamp.tmp');
    final backup = File('${registry.path}.relink-$stamp.bak');
    await temporary.writeAsString(replacement, flush: true);

    var originalMoved = false;
    try {
      await registry.rename(backup.path);
      originalMoved = true;
      await temporary.rename(registry.path);
      if (await backup.exists()) await backup.delete();
    } catch (error, stackTrace) {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_, cleanupStackTrace) {
        _debugRecoveryFailure('temporary cleanup', cleanupStackTrace);
      }
      if (originalMoved && await backup.exists()) {
        try {
          if (await registry.exists()) await registry.delete();
          await backup.rename(registry.path);
        } catch (_, restoreStackTrace) {
          _debugRecoveryFailure('backup restore', restoreStackTrace);
          try {
            if (!await registry.exists()) {
              await registry.writeAsString(original, flush: true);
            }
          } catch (_, fallbackStackTrace) {
            _debugRecoveryFailure('fallback registry restore', fallbackStackTrace);
          }
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _debugRecoveryFailure(String operation, StackTrace stackTrace) {
    assert(() {
      stderr.writeln('Vault registry recovery: $operation failed.');
      stderr.writeln(stackTrace);
      return true;
    }());
  }
}
