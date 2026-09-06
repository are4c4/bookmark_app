import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_lifecycle_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = DatabaseProfile(
  id: 'vault',
  name: 'Vault',
  databaseName: 'vault-db',
  directoryPath: '/tmp/Vault',
);

const _state = ProfileState(
  profiles: [_profile],
  activeProfileId: 'vault',
);

void main() {
  testWidgets('Vault lifecycle scope exposes app-level operations to descendants',
      (tester) async {
    var createCount = 0;
    var openCount = 0;
    DatabaseProfile? switched;
    VaultLifecycleScope? observed;

    await tester.pumpWidget(
      VaultLifecycleScope(
        profileState: _state,
        createVault: () async => createCount++,
        openVault: () async => openCount++,
        switchVault: (profile) async => switched = profile,
        child: Builder(
          builder: (context) {
            observed = VaultLifecycleScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(observed?.profileState.activeProfile.id, 'vault');
    await observed!.createVault();
    await observed!.openVault();
    await observed!.switchVault(_profile);

    expect(createCount, 1);
    expect(openCount, 1);
    expect(switched?.id, 'vault');
  });

  testWidgets('maybeOf remains null outside a Vault lifecycle host',
      (tester) async {
    VaultLifecycleScope? observed;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          observed = VaultLifecycleScope.maybeOf(context);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(observed, isNull);
  });
}
