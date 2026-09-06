import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_directory_picker_service.dart';
import 'package:bookmark_app/services/vault_move_lifecycle_controller.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseProfile _profile(String id, String path) => DatabaseProfile(
      id: id,
      name: 'Vault $id',
      databaseName: 'BookmarkApp/Profiles/$id/database',
      directoryPath: path,
    );

void main() {
  test('runs prepare, copy, registry commit and target activation in order',
      () async {
    final source = _profile('active', '/vault/source');
    final target = _profile('active', '/vault/target');
    final events = <String>[];
    final controller = VaultMoveLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => target.directoryPath,
      ),
      prepareSource: (_) async => events.add('prepare'),
      copyPreparedVault: ({required profile, required targetDirectoryPath}) async {
        events.add('copy:$targetDirectoryPath');
        return target;
      },
      commitMovedVault: ({
        required source,
        required target,
        required verifyTarget,
      }) async {
        events.add('commit:${target.directoryPath}');
        await verifyTarget(target);
      },
      activateTarget: (_) async => events.add('activate'),
      restoreSource: (_) async => events.add('restore'),
    );

    final moved = await controller.moveActiveVault(source);

    expect(moved?.directoryPath, target.directoryPath);
    expect(
      events,
      ['prepare', 'copy:/vault/target', 'commit:/vault/target', 'activate'],
    );
  });

  test('cancelled target selection performs no Vault mutation', () async {
    final events = <String>[];
    final controller = VaultMoveLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      prepareSource: (_) async => events.add('prepare'),
      copyPreparedVault: ({required profile, required targetDirectoryPath}) async {
        events.add('copy');
        return profile;
      },
      commitMovedVault: ({
        required source,
        required target,
        required verifyTarget,
      }) async => events.add('commit'),
      activateTarget: (_) async => events.add('activate'),
      restoreSource: (_) async => events.add('restore'),
    );

    expect(await controller.moveActiveVault(_profile('active', '/vault/source')), isNull);
    expect(events, isEmpty);
  });

  test('copy failure restores the prepared source and preserves primary error',
      () async {
    final source = _profile('active', '/vault/source');
    final events = <String>[];
    final controller = VaultMoveLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => '/vault/target',
      ),
      prepareSource: (_) async => events.add('prepare'),
      copyPreparedVault: ({required profile, required targetDirectoryPath}) async {
        events.add('copy');
        throw StateError('copy failed');
      },
      commitMovedVault: ({
        required source,
        required target,
        required verifyTarget,
      }) async => events.add('commit'),
      activateTarget: (_) async => events.add('activate'),
      restoreSource: (_) async => events.add('restore'),
    );

    await expectLater(
      controller.moveActiveVault(source),
      throwsA(
        isA<StateError>().having((error) => error.message, 'message', 'copy failed'),
      ),
    );
    expect(events, ['prepare', 'copy', 'restore']);
  });

  test('registry/reopen failure restores the source after commit rollback',
      () async {
    final source = _profile('active', '/vault/source');
    final target = _profile('active', '/vault/target');
    final events = <String>[];
    final controller = VaultMoveLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => target.directoryPath,
      ),
      prepareSource: (_) async => events.add('prepare'),
      copyPreparedVault: ({required profile, required targetDirectoryPath}) async {
        events.add('copy');
        return target;
      },
      commitMovedVault: ({
        required source,
        required target,
        required verifyTarget,
      }) async {
        events.add('commit');
        try {
          await verifyTarget(target);
        } catch (_) {
          events.add('registry-rollback');
          rethrow;
        }
      },
      activateTarget: (_) async {
        events.add('activate');
        throw StateError('reopen failed');
      },
      restoreSource: (_) async => events.add('restore'),
    );

    await expectLater(
      controller.moveActiveVault(source),
      throwsA(
        isA<StateError>()
            .having((error) => error.message, 'message', 'reopen failed'),
      ),
    );
    expect(
      events,
      ['prepare', 'copy', 'commit', 'activate', 'registry-rollback', 'restore'],
    );
  });

  test('prepare failure does not attempt source restore', () async {
    final events = <String>[];
    final controller = VaultMoveLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => '/vault/target',
      ),
      prepareSource: (_) async {
        events.add('prepare');
        throw StateError('checkpoint failed');
      },
      copyPreparedVault: ({required profile, required targetDirectoryPath}) async {
        events.add('copy');
        return profile;
      },
      commitMovedVault: ({
        required source,
        required target,
        required verifyTarget,
      }) async => events.add('commit'),
      activateTarget: (_) async => events.add('activate'),
      restoreSource: (_) async => events.add('restore'),
    );

    await expectLater(
      controller.moveActiveVault(_profile('active', '/vault/source')),
      throwsA(isA<StateError>()),
    );
    expect(events, ['prepare']);
  });

  test('source restore failure never replaces the primary move failure', () async {
    final controller = VaultMoveLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => '/vault/target',
      ),
      prepareSource: (_) async {},
      copyPreparedVault: ({required profile, required targetDirectoryPath}) async =>
          throw ArgumentError('primary'),
      commitMovedVault: ({
        required source,
        required target,
        required verifyTarget,
      }) async {},
      activateTarget: (_) async {},
      restoreSource: (_) async => throw StateError('restore failed'),
    );

    await expectLater(
      controller.moveActiveVault(_profile('active', '/vault/source')),
      throwsA(
        isA<ArgumentError>().having((error) => error.message, 'message', 'primary'),
      ),
    );
  });

  test('same source and target path fails before checkpointing', () async {
    var prepared = false;
    final controller = VaultMoveLifecycleController(
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => '/vault/source',
      ),
      prepareSource: (_) async => prepared = true,
      copyPreparedVault: ({required profile, required targetDirectoryPath}) async =>
          profile,
      commitMovedVault: ({
        required source,
        required target,
        required verifyTarget,
      }) async {},
      activateTarget: (_) async {},
      restoreSource: (_) async {},
    );

    await expectLater(
      controller.moveActiveVault(_profile('active', '/vault/source')),
      throwsA(isA<StateError>()),
    );
    expect(prepared, isFalse);
  });
}
