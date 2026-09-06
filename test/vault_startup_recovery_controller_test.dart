import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_availability_service.dart';
import 'package:bookmark_app/services/vault_directory_picker_service.dart';
import 'package:bookmark_app/services/vault_registry_inspection_service.dart';
import 'package:bookmark_app/services/vault_startup_recovery_controller.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseProfile _profile(String id, String path) => DatabaseProfile(
      id: id,
      name: id,
      databaseName: 'BookmarkApp/Profiles/$id/database',
      directoryPath: path,
    );

VaultRegistryLocation _location({
  required String id,
  bool active = false,
}) =>
    VaultRegistryLocation(
      profile: _profile(id, '/missing/$id'),
      availability: VaultAvailability.missingDirectory,
      isActive: active,
    );

void main() {
  test('inspect delegates without mutating recovery state', () async {
    final locations = [_location(id: 'active', active: true)];
    final controller = VaultStartupRecoveryController(
      inspectRegistry: () async => locations,
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      relinkRegistry: ({required profileId, required directoryPath}) async =>
          _profile(profileId, directoryPath),
      unregisterRegistryEntry: (_) async {},
    );

    expect(await controller.inspect(), same(locations));
  });

  test('relink cancellation performs no registry mutation', () async {
    var relinkCalls = 0;
    final controller = VaultStartupRecoveryController(
      inspectRegistry: () async => const [],
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      relinkRegistry: ({required profileId, required directoryPath}) async {
        relinkCalls++;
        return _profile(profileId, directoryPath);
      },
      unregisterRegistryEntry: (_) async {},
    );

    expect(await controller.relink(_location(id: 'active', active: true)), isFalse);
    expect(relinkCalls, 0);
  });

  test('relink sends selected folder only for the requested Vault id', () async {
    String? id;
    String? path;
    final controller = VaultStartupRecoveryController(
      inspectRegistry: () async => const [],
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => '/Volumes/Data/Moved Vault',
      ),
      relinkRegistry: ({required profileId, required directoryPath}) async {
        id = profileId;
        path = directoryPath;
        return _profile(profileId, directoryPath);
      },
      unregisterRegistryEntry: (_) async {},
    );

    expect(await controller.relink(_location(id: 'target', active: true)), isTrue);
    expect(id, 'target');
    expect(path, '/Volumes/Data/Moved Vault');
  });

  test('inactive unregister delegates by id', () async {
    String? removedId;
    final controller = VaultStartupRecoveryController(
      inspectRegistry: () async => const [],
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      relinkRegistry: ({required profileId, required directoryPath}) async =>
          _profile(profileId, directoryPath),
      unregisterRegistryEntry: (profileId) async => removedId = profileId,
    );

    await controller.unregisterInactive(_location(id: 'archive'));
    expect(removedId, 'archive');
  });

  test('active unregister fails before registry callback', () async {
    var unregisterCalls = 0;
    final controller = VaultStartupRecoveryController(
      inspectRegistry: () async => const [],
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      relinkRegistry: ({required profileId, required directoryPath}) async =>
          _profile(profileId, directoryPath),
      unregisterRegistryEntry: (_) async => unregisterCalls++,
    );

    await expectLater(
      controller.unregisterInactive(_location(id: 'active', active: true)),
      throwsA(isA<StateError>()),
    );
    expect(unregisterCalls, 0);
  });
}
