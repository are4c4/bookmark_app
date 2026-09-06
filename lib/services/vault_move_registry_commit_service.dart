import 'dart:io';

import 'profile_manager.dart';
import 'vault_registry_inspection_service.dart';
import 'vault_registry_recovery_service.dart';

typedef InspectVaultRegistry = Future<List<VaultRegistryLocation>> Function();
typedef RelinkVaultRegistry = Future<DatabaseProfile> Function({
  required String profileId,
  required String directoryPath,
});
typedef VerifyMovedVault = Future<void> Function(DatabaseProfile target);

/// Commits a previously copied/validated active Vault to its new registry path.
///
/// Physical copy is deliberately outside this service. The caller must provide
/// a [target] returned by the safe move-copy boundary. Registry mutation happens
/// before [verifyTarget] so the normal bootstrap/reopen path observes the new
/// location. If that verification fails, the registry is pointed back at the
/// untouched source before the original failure is rethrown.
class VaultMoveRegistryCommitService {
  const VaultMoveRegistryCommitService({
    required this.inspectRegistry,
    required this.relinkRegistry,
  });

  factory VaultMoveRegistryCommitService.fromServices({
    VaultRegistryInspectionService inspection =
        const VaultRegistryInspectionService(),
    VaultRegistryRecoveryService recovery =
        const VaultRegistryRecoveryService(),
  }) =>
      VaultMoveRegistryCommitService(
        inspectRegistry: inspection.inspect,
        relinkRegistry: recovery.relink,
      );

  final InspectVaultRegistry inspectRegistry;
  final RelinkVaultRegistry relinkRegistry;

  Future<void> commitAndVerify({
    required DatabaseProfile source,
    required DatabaseProfile target,
    required VerifyMovedVault verifyTarget,
  }) async {
    if (source.id != target.id) {
      throw StateError('Vault move source and target identifiers do not match.');
    }
    if (_sameDirectory(source.directoryPath, target.directoryPath)) {
      throw StateError('Vault move target must differ from the source.');
    }

    final locations = await inspectRegistry();
    final matches = locations
        .where((location) => location.profile.id == source.id)
        .toList(growable: false);
    if (matches.length != 1) {
      throw StateError('The source Vault is not uniquely registered.');
    }
    final registered = matches.single;
    if (!registered.isActive) {
      throw StateError('Only the active Vault can be moved.');
    }
    if (!_sameDirectory(
      registered.profile.directoryPath,
      source.directoryPath,
    )) {
      throw StateError('The registered Vault location changed during the move.');
    }
    final targetIsRegisteredElsewhere = locations.any(
      (location) =>
          location.profile.id != source.id &&
          _sameDirectory(location.profile.directoryPath, target.directoryPath),
    );
    if (targetIsRegisteredElsewhere) {
      throw StateError('The move target is already registered as another Vault.');
    }

    await relinkRegistry(
      profileId: source.id,
      directoryPath: target.directoryPath,
    );
    try {
      await verifyTarget(target);
    } catch (error, stackTrace) {
      try {
        await relinkRegistry(
          profileId: source.id,
          directoryPath: source.directoryPath,
        );
      } catch (_, rollbackStackTrace) {
        _debugRollbackFailure(rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  bool _sameDirectory(String left, String right) =>
      Directory(left).absolute.path == Directory(right).absolute.path;

  void _debugRollbackFailure(StackTrace stackTrace) {
    assert(() {
      stderr.writeln('Vault move registry rollback failed.');
      stderr.writeln(stackTrace);
      return true;
    }());
  }
}
