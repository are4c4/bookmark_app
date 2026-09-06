import 'dart:io';

import 'profile_manager.dart';

enum VaultAvailability {
  available,
  missingDirectory,
  missingDatabase,
}

class VaultAvailabilityService {
  const VaultAvailabilityService();

  Future<VaultAvailability> check(DatabaseProfile profile) async {
    final directory = Directory(profile.directoryPath);
    if (!await directory.exists()) {
      return VaultAvailability.missingDirectory;
    }
    if (!await File(profile.databasePath).exists()) {
      return VaultAvailability.missingDatabase;
    }
    return VaultAvailability.available;
  }
}
