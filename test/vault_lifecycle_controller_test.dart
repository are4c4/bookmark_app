import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_directory_picker_service.dart';
import 'package:bookmark_app/services/vault_lifecycle_controller.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseProfile _profile(String id, String path) => DatabaseProfile(
      id: id,
      name: id,
      databaseName: '$id-db',
      directoryPath: path,
    );

void main() {
  test('createVault picks a folder, creates it, then verifies the switch',
      () async {
    const path = '/Users/example/New Vault';
    var activeId = 'old';
    String? createdName;
    String? createdPath;
    final created = _profile('new', path);
    final controller = VaultLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => path,
      ),
      createProfile: ({required name, required directoryPath}) async {
        createdName = name;
        createdPath = directoryPath;
        return created;
      },
      openProfile: (_) async => throw UnimplementedError(),
      switchProfile: (profile) async => activeId = profile.id,
      activeVaultId: () => activeId,
    );

    expect(await controller.createVault(), isTrue);
    expect(createdName, 'New Vault');
    expect(createdPath, path);
    expect(activeId, 'new');
  });

  test('openVault opens the selected folder in place before switching', () async {
    const path = '/Volumes/Data/Portable Vault';
    var activeId = 'old';
    String? openedPath;
    final opened = _profile('portable', path);
    final controller = VaultLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => path,
      ),
      createProfile: ({required name, required directoryPath}) async =>
          throw UnimplementedError(),
      openProfile: (directoryPath) async {
        openedPath = directoryPath;
        return opened;
      },
      switchProfile: (profile) async => activeId = profile.id,
      activeVaultId: () => activeId,
    );

    expect(await controller.openVault(), isTrue);
    expect(openedPath, path);
    expect(activeId, 'portable');
  });

  test('cancelled folder selection leaves registry and switch callbacks untouched',
      () async {
    var createCalled = false;
    var openCalled = false;
    var switchCalled = false;
    final controller = VaultLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      createProfile: ({required name, required directoryPath}) async {
        createCalled = true;
        return _profile('new', directoryPath);
      },
      openProfile: (directoryPath) async {
        openCalled = true;
        return _profile('open', directoryPath);
      },
      switchProfile: (_) async => switchCalled = true,
      activeVaultId: () => 'old',
    );

    expect(await controller.createVault(), isFalse);
    expect(await controller.openVault(), isFalse);
    expect(createCalled, isFalse);
    expect(openCalled, isFalse);
    expect(switchCalled, isFalse);
  });

  test('switchVault succeeds only after the requested Vault is active', () async {
    var activeId = 'previous';
    final target = _profile('target', '/tmp/Target');
    final controller = VaultLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      createProfile: ({required name, required directoryPath}) async => target,
      openProfile: (_) async => target,
      switchProfile: (profile) async => activeId = profile.id,
      activeVaultId: () => activeId,
    );

    await controller.switchVault(target);

    expect(activeId, 'target');
  });

  test('switch verification fails closed when host rolls back to previous Vault',
      () async {
    final target = _profile('target', '/tmp/Target');
    final controller = VaultLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      createProfile: ({required name, required directoryPath}) async => target,
      openProfile: (_) async => target,
      switchProfile: (_) async {},
      activeVaultId: () => 'previous',
    );

    await expectLater(
      controller.switchVault(target),
      throwsA(isA<StateError>()),
    );
  });
}
