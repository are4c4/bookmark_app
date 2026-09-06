import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vault lifecycle is wired through the existing Profile switch host', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('VaultLifecycleController.fromManager('));
    expect(source, contains('switchProfile: _switchProfile'));
    expect(source, contains('home = VaultLifecycleScope('));
    expect(source, contains('profileState: manager.state'));
    expect(source, contains('await vaultLifecycle.createVault();'));
    expect(source, contains('await vaultLifecycle.openVault();'));
    expect(source, contains('switchVault: vaultLifecycle.switchVault'));
  });
}
