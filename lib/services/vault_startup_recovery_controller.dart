import 'profile_manager.dart';
import 'vault_directory_picker_service.dart';
import 'vault_registry_inspection_service.dart';
import 'vault_registry_recovery_service.dart';

typedef InspectStartupVaults = Future<List<VaultRegistryLocation>> Function();
typedef RelinkStartupVault = Future<DatabaseProfile> Function({
  required String profileId,
  required String directoryPath,
});
typedef UnregisterStartupVault = Future<void> Function(String profileId);

/// Composes the pre-bootstrap Vault recovery boundaries without owning app
/// bootstrap or database state.
class VaultStartupRecoveryController {
  const VaultStartupRecoveryController({
    required this.inspectRegistry,
    required this.directoryPicker,
    required this.relinkRegistry,
    required this.unregisterRegistryEntry,
  });

  factory VaultStartupRecoveryController.fromServices({
    VaultRegistryInspectionService inspection =
        const VaultRegistryInspectionService(),
    VaultDirectoryPickerService directoryPicker =
        const VaultDirectoryPickerService(),
    VaultRegistryRecoveryService recovery =
        const VaultRegistryRecoveryService(),
  }) =>
      VaultStartupRecoveryController(
        inspectRegistry: inspection.inspect,
        directoryPicker: directoryPicker,
        relinkRegistry: recovery.relink,
        unregisterRegistryEntry: recovery.unregisterInactive,
      );

  final InspectStartupVaults inspectRegistry;
  final VaultDirectoryPickerService directoryPicker;
  final RelinkStartupVault relinkRegistry;
  final UnregisterStartupVault unregisterRegistryEntry;

  Future<List<VaultRegistryLocation>> inspect() => inspectRegistry();

  Future<bool> relink(VaultRegistryLocation location) async {
    final selectedPath = await directoryPicker.pickDirectory();
    if (selectedPath == null) return false;
    await relinkRegistry(
      profileId: location.profile.id,
      directoryPath: selectedPath,
    );
    return true;
  }

  Future<void> unregisterInactive(VaultRegistryLocation location) async {
    if (location.isActive) {
      throw StateError('The active Vault cannot be unregistered during recovery.');
    }
    await unregisterRegistryEntry(location.profile.id);
  }
}
