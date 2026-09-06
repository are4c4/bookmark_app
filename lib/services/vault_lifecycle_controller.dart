import 'profile_manager.dart';
import 'vault_directory_picker_service.dart';

typedef CreateVaultProfile = Future<DatabaseProfile> Function({
  required String name,
  required String directoryPath,
});
typedef OpenVaultProfile = Future<DatabaseProfile> Function(String directoryPath);
typedef SwitchVaultProfile = Future<void> Function(DatabaseProfile profile);
typedef ActiveVaultId = String Function();

class VaultLifecycleController {
  const VaultLifecycleController({
    required this.directoryPicker,
    required this.createProfile,
    required this.openProfile,
    required this.switchProfile,
    required this.activeVaultId,
  });

  factory VaultLifecycleController.fromManager({
    required ProfileManager manager,
    required SwitchVaultProfile switchProfile,
    VaultDirectoryPickerService directoryPicker =
        const VaultDirectoryPickerService(),
  }) =>
      VaultLifecycleController(
        directoryPicker: directoryPicker,
        createProfile: manager.createVault,
        openProfile: manager.openVault,
        switchProfile: switchProfile,
        activeVaultId: () => manager.state.activeProfile.id,
      );

  final VaultDirectoryPickerService directoryPicker;
  final CreateVaultProfile createProfile;
  final OpenVaultProfile openProfile;
  final SwitchVaultProfile switchProfile;
  final ActiveVaultId activeVaultId;

  Future<bool> createVault() async {
    final path = await directoryPicker.pickDirectory();
    if (path == null) return false;
    final profile = await createProfile(
      name: directoryPicker.suggestedVaultName(path),
      directoryPath: path,
    );
    await _switchAndVerify(profile);
    return true;
  }

  Future<bool> openVault() async {
    final path = await directoryPicker.pickDirectory();
    if (path == null) return false;
    final profile = await openProfile(path);
    await _switchAndVerify(profile);
    return true;
  }

  Future<void> switchVault(DatabaseProfile profile) => _switchAndVerify(profile);

  Future<void> _switchAndVerify(DatabaseProfile profile) async {
    await switchProfile(profile);
    if (activeVaultId() != profile.id) {
      throw StateError('Vault switch did not complete.');
    }
  }
}
