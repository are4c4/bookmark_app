import 'dart:io';

import 'profile_manager.dart';
import 'vault_directory_picker_service.dart';
import 'vault_move_copy_service.dart';
import 'vault_move_registry_commit_service.dart';

typedef PrepareVaultMove = Future<void> Function(DatabaseProfile source);
typedef CopyPreparedVault = Future<DatabaseProfile> Function({
  required DatabaseProfile profile,
  required String targetDirectoryPath,
});
typedef CommitMovedVault = Future<void> Function({
  required DatabaseProfile source,
  required DatabaseProfile target,
  required VerifyMovedVault verifyTarget,
});
typedef ActivateMovedVault = Future<void> Function(DatabaseProfile target);
typedef RestoreSourceVault = Future<void> Function(DatabaseProfile source);

/// Coordinates the destructive-looking stages of Vault move without deleting
/// the source Vault.
///
/// The host owns database checkpoint/close/reopen. This controller owns only
/// ordering and failure recovery around the already-isolated copy and registry
/// commit primitives.
class VaultMoveLifecycleController {
  const VaultMoveLifecycleController({
    required this.directoryPicker,
    required this.prepareSource,
    required this.copyPreparedVault,
    required this.commitMovedVault,
    required this.activateTarget,
    required this.restoreSource,
  });

  factory VaultMoveLifecycleController.fromServices({
    required PrepareVaultMove prepareSource,
    required ActivateMovedVault activateTarget,
    required RestoreSourceVault restoreSource,
    VaultDirectoryPickerService directoryPicker =
        const VaultDirectoryPickerService(),
    VaultMoveCopyService copyService = const VaultMoveCopyService(),
    VaultMoveRegistryCommitService? registryCommit,
  }) {
    final commit =
        registryCommit ?? VaultMoveRegistryCommitService.fromServices();
    return VaultMoveLifecycleController(
      directoryPicker: directoryPicker,
      prepareSource: prepareSource,
      copyPreparedVault: copyService.copyPreparedVault,
      commitMovedVault: commit.commitAndVerify,
      activateTarget: activateTarget,
      restoreSource: restoreSource,
    );
  }

  final VaultDirectoryPickerService directoryPicker;
  final PrepareVaultMove prepareSource;
  final CopyPreparedVault copyPreparedVault;
  final CommitMovedVault commitMovedVault;
  final ActivateMovedVault activateTarget;
  final RestoreSourceVault restoreSource;

  Future<DatabaseProfile?> moveActiveVault(DatabaseProfile source) async {
    final targetPath = await directoryPicker.pickDirectory();
    if (targetPath == null) return null;
    if (_sameDirectory(source.directoryPath, targetPath)) {
      throw StateError('Vault move target must differ from the source.');
    }

    var sourcePrepared = false;
    try {
      await prepareSource(source);
      sourcePrepared = true;
      final target = await copyPreparedVault(
        profile: source,
        targetDirectoryPath: targetPath,
      );
      await commitMovedVault(
        source: source,
        target: target,
        verifyTarget: activateTarget,
      );
      return target;
    } catch (error, stackTrace) {
      if (sourcePrepared) {
        try {
          await restoreSource(source);
        } catch (_, restoreStackTrace) {
          _debugRestoreFailure(restoreStackTrace);
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  bool _sameDirectory(String left, String right) =>
      Directory(left).absolute.path == Directory(right).absolute.path;

  void _debugRestoreFailure(StackTrace stackTrace) {
    assert(() {
      stderr.writeln('Vault move source restore failed.');
      stderr.writeln(stackTrace);
      return true;
    }());
  }
}
