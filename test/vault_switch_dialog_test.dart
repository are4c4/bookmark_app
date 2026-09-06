import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/views/vault_switch_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _state = ProfileState(
  activeProfileId: 'one',
  profiles: [
    DatabaseProfile(
      id: 'one',
      name: 'Main Vault',
      databaseName: 'main',
      directoryPath: '/Users/example/Main Vault',
    ),
    DatabaseProfile(
      id: 'two',
      name: 'Portable Vault',
      databaseName: 'portable',
      directoryPath: '/Volumes/Data/Portable Vault',
    ),
  ],
);

void main() {
  testWidgets('Vault switch dialog shows names paths and active state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showVaultSwitchDialog(context, state: _state),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Vaultを切り替える'), findsOneWidget);
    expect(find.text('Main Vault'), findsOneWidget);
    expect(find.text('/Users/example/Main Vault'), findsOneWidget);
    expect(find.text('Portable Vault'), findsOneWidget);
    expect(find.text('/Volumes/Data/Portable Vault'), findsOneWidget);

    final activeTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Main Vault'),
    );
    expect(activeTile.selected, isTrue);
    expect(activeTile.onTap, isNull);
  });

  testWidgets('Vault switch dialog returns only an explicit non-active choice',
      (tester) async {
    DatabaseProfile? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              selected = await showVaultSwitchDialog(context, state: _state);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portable Vault'));
    await tester.pumpAndSettle();

    expect(selected?.id, 'two');
  });
}
