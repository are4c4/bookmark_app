import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_availability_service.dart';
import 'package:bookmark_app/services/vault_move_registry_commit_service.dart';
import 'package:bookmark_app/services/vault_registry_inspection_service.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseProfile _profile(String id, String path) => DatabaseProfile(
      id: id,
      name: 'Vault $id',
      databaseName: 'BookmarkApp/Profiles/$id/database',
      directoryPath: path,
    );

VaultRegistryLocation _location(
  DatabaseProfile profile, {
  required bool active,
}) =>
    VaultRegistryLocation(
      profile: profile,
      availability: VaultAvailability.available,
      isActive: active,
    );

void main() {
  test('commits target path before verifying the reopened Vault', () async {
    final source = _profile('active', '/vault/source');
    final target = _profile('active', '/vault/target');
    final events = <String>[];
    final service = VaultMoveRegistryCommitService(
      inspectRegistry: () async => [_location(source, active: true)],
      relinkRegistry: ({required profileId, required directoryPath}) async {
        events.add('relink:$directoryPath');
        return _profile(profileId, directoryPath);
      },
    );

    await service.commitAndVerify(
      source: source,
      target: target,
      verifyTarget: (candidate) async {
        events.add('verify:${candidate.directoryPath}');
      },
    );

    expect(events, ['relink:/vault/target', 'verify:/vault/target']);
  });

  test('verification failure restores the source registry path', () async {
    final source = _profile('active', '/vault/source');
    final target = _profile('active', '/vault/target');
    final events = <String>[];
    final service = VaultMoveRegistryCommitService(
      inspectRegistry: () async => [_location(source, active: true)],
      relinkRegistry: ({required profileId, required directoryPath}) async {
        events.add('relink:$directoryPath');
        return _profile(profileId, directoryPath);
      },
    );

    await expectLater(
      service.commitAndVerify(
        source: source,
        target: target,
        verifyTarget: (_) async {
          events.add('verify');
          throw StateError('target reopen failed');
        },
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'target reopen failed',
        ),
      ),
    );

    expect(
      events,
      ['relink:/vault/target', 'verify', 'relink:/vault/source'],
    );
  });

  test('rollback failure never replaces the primary target verification error',
      () async {
    final source = _profile('active', '/vault/source');
    final target = _profile('active', '/vault/target');
    var relinkCalls = 0;
    final service = VaultMoveRegistryCommitService(
      inspectRegistry: () async => [_location(source, active: true)],
      relinkRegistry: ({required profileId, required directoryPath}) async {
        relinkCalls++;
        if (relinkCalls == 2) throw StateError('rollback failed');
        return _profile(profileId, directoryPath);
      },
    );

    await expectLater(
      service.commitAndVerify(
        source: source,
        target: target,
        verifyTarget: (_) async => throw ArgumentError('primary failure'),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          'primary failure',
        ),
      ),
    );
    expect(relinkCalls, 2);
  });

  test('refuses a stale source path before registry mutation', () async {
    final source = _profile('active', '/vault/source');
    final target = _profile('active', '/vault/target');
    final registered = _profile('active', '/vault/already-moved');
    var relinkCalls = 0;
    final service = VaultMoveRegistryCommitService(
      inspectRegistry: () async => [_location(registered, active: true)],
      relinkRegistry: ({required profileId, required directoryPath}) async {
        relinkCalls++;
        return _profile(profileId, directoryPath);
      },
    );

    await expectLater(
      service.commitAndVerify(
        source: source,
        target: target,
        verifyTarget: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );
    expect(relinkCalls, 0);
  });

  test('refuses moving an inactive Vault', () async {
    final source = _profile('archive', '/vault/archive');
    final target = _profile('archive', '/vault/archive-moved');
    var relinkCalls = 0;
    final service = VaultMoveRegistryCommitService(
      inspectRegistry: () async => [_location(source, active: false)],
      relinkRegistry: ({required profileId, required directoryPath}) async {
        relinkCalls++;
        return _profile(profileId, directoryPath);
      },
    );

    await expectLater(
      service.commitAndVerify(
        source: source,
        target: target,
        verifyTarget: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );
    expect(relinkCalls, 0);
  });

  test('refuses a target path already owned by another registered Vault',
      () async {
    final source = _profile('active', '/vault/source');
    final target = _profile('active', '/vault/target');
    final other = _profile('other', '/vault/target');
    var relinkCalls = 0;
    final service = VaultMoveRegistryCommitService(
      inspectRegistry: () async => [
        _location(source, active: true),
        _location(other, active: false),
      ],
      relinkRegistry: ({required profileId, required directoryPath}) async {
        relinkCalls++;
        return _profile(profileId, directoryPath);
      },
    );

    await expectLater(
      service.commitAndVerify(
        source: source,
        target: target,
        verifyTarget: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );
    expect(relinkCalls, 0);
  });

  test('source and target identifiers must match before any lookup', () async {
    var inspections = 0;
    final service = VaultMoveRegistryCommitService(
      inspectRegistry: () async {
        inspections++;
        return const [];
      },
      relinkRegistry: ({required profileId, required directoryPath}) async =>
          _profile(profileId, directoryPath),
    );

    await expectLater(
      service.commitAndVerify(
        source: _profile('source', '/vault/source'),
        target: _profile('different', '/vault/target'),
        verifyTarget: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );
    expect(inspections, 0);
  });
}
