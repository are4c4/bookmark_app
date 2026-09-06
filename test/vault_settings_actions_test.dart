import 'package:bookmark_app/views/vault_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  VoidCallback? onCreateVault,
  VoidCallback? onOpenVault,
  VoidCallback? onSwitchVault,
  VoidCallback? onMoveVault,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: VaultSettingsSection(
            directoryPath: '/Users/example/Documents/My Vault',
            revealDirectory: (_) async {},
            onCreateVault: onCreateVault,
            onOpenVault: onOpenVault,
            onSwitchVault: onSwitchVault,
            onMoveVault: onMoveVault,
          ),
        ),
      ),
    );

void main() {
  testWidgets('Vault management actions route to host callbacks', (tester) async {
    var createCount = 0;
    var openCount = 0;
    var switchCount = 0;
    var moveCount = 0;

    await tester.pumpWidget(
      _host(
        onCreateVault: () => createCount++,
        onOpenVault: () => openCount++,
        onSwitchVault: () => switchCount++,
        onMoveVault: () => moveCount++,
      ),
    );

    await tester.tap(find.text('新しいVaultを作成'));
    await tester.tap(find.text('既存のVaultを開く'));
    await tester.tap(find.text('Vaultを切り替える'));
    await tester.tap(find.text('Vaultを移動'));
    await tester.pump();

    expect(createCount, 1);
    expect(openCount, 1);
    expect(switchCount, 1);
    expect(moveCount, 1);
  });

  testWidgets('Vault management actions stay hidden until host wiring exists',
      (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text('Finderで表示'), findsOneWidget);
    expect(find.text('新しいVaultを作成'), findsNothing);
    expect(find.text('既存のVaultを開く'), findsNothing);
    expect(find.text('Vaultを切り替える'), findsNothing);
    expect(find.text('Vaultを移動'), findsNothing);
  });
}
