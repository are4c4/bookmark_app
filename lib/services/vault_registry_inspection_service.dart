import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'profile_manager.dart';
import 'vault_availability_service.dart';

class VaultRegistryLocation {
  const VaultRegistryLocation({
    required this.profile,
    required this.availability,
    required this.isActive,
  });

  final DatabaseProfile profile;
  final VaultAvailability availability;
  final bool isActive;

  bool get isAvailable => availability == VaultAvailability.available;
}

/// Reads persisted Vault registry locations without initializing ProfileManager.
///
/// This is used by startup recovery when the active custom Vault is missing and
/// `ProfileManager.load()` therefore cannot complete. It never creates Vault
/// folders, databases, metadata, or registry files.
class VaultRegistryInspectionService {
  const VaultRegistryInspectionService({
    this.applicationSupportDirectoryProvider,
    this.applicationDocumentsDirectoryProvider,
    this.availability = const VaultAvailabilityService(),
  });

  final Future<Directory> Function()? applicationSupportDirectoryProvider;
  final Future<Directory> Function()? applicationDocumentsDirectoryProvider;
  final VaultAvailabilityService availability;

  Future<List<VaultRegistryLocation>> inspect() async {
    final support = await (applicationSupportDirectoryProvider ??
        getApplicationSupportDirectory)();
    final documents = await (applicationDocumentsDirectoryProvider ??
        getApplicationDocumentsDirectory)();
    final registry = File('${support.path}/bookmark_profiles.json');
    if (!await registry.exists()) return const <VaultRegistryLocation>[];

    final Object? decoded;
    try {
      decoded = jsonDecode(await registry.readAsString());
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
    final activeProfileId = root['activeProfileId'];
    final locations = <VaultRegistryLocation>[];
    final seenIds = <String>{};

    for (final raw in rawProfiles) {
      if (raw is! Map) {
        throw const FormatException('Vault registry is invalid.');
      }
      final value = Map<String, Object?>.from(raw);
      final id = value['id'];
      final name = value['name'];
      if (id is! String ||
          id.trim().isEmpty ||
          name is! String ||
          name.trim().isEmpty ||
          !seenIds.add(id.trim())) {
        throw const FormatException('Vault registry is invalid.');
      }

      final normalizedId = id.trim();
      final storedPath = value['directoryPath'];
      if (storedPath != null && storedPath is! String) {
        throw const FormatException('Vault registry is invalid.');
      }
      final path = storedPath is String && storedPath.trim().isNotEmpty
          ? storedPath.trim()
          : '${documents.path}/BookmarkApp/Profiles/$normalizedId';
      final storedDatabaseName = value['databaseName'];
      if (storedDatabaseName != null && storedDatabaseName is! String) {
        throw const FormatException('Vault registry is invalid.');
      }
      final profile = DatabaseProfile(
        id: normalizedId,
        name: name.trim(),
        databaseName:
            storedDatabaseName is String && storedDatabaseName.trim().isNotEmpty
                ? storedDatabaseName.trim()
                : 'BookmarkApp/Profiles/$normalizedId/database',
        directoryPath: path,
      );
      locations.add(
        VaultRegistryLocation(
          profile: profile,
          availability: await availability.check(profile),
          isActive: activeProfileId == normalizedId,
        ),
      );
    }

    return List<VaultRegistryLocation>.unmodifiable(locations);
  }
}
