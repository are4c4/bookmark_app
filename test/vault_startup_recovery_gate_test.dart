import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_availability_service.dart';
import 'package:bookmark_app/services/vault_directory_picker_service.dart';
import 'package:bookmark_app/services/vault_registry_inspection_service.dart';
import 'package:bookmark_app/services/vault_startup_recovery_controller.dart';
import 'package:bookmark_app/views/vault_startup_recovery_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseProfile _profile(String path) => DatabaseProfile(
      id: 'active',
      name: 'Active Vault',
      databaseName: 'BookmarkApp/Profiles/active/database',
      directoryPath: path,
    );

VaultRegistryLocation _location(
  String path,
  VaultAvailability availability,
) =>
    VaultRegistryLocation(
      profile: _profile(path),
      availability: availability,
      isActive: true,
    );

Widget _host({
  required VaultStartupRecoveryController controller,
  required Future<void> Function() onRetry,
}) =>
    MaterialApp(
      home: VaultStartupRecoveryGate(
        controller: controller,
        onRetryBootstrap: onRetry,
      ),
    );

void main() {
  testWidgets('shows unavailable Vaults discovered before normal bootstrap',
      (tester) async {
    final controller = VaultStartupRecoveryController(
      inspectRegistry: () async => [
        _location('/missing/active', VaultAvailability.missingDirectory),
      ],
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      relinkRegistry: ({required profileId, required directoryPath}) async =>
          _profile(directoryPath),
      unregisterRegistryEntry: (_) async {},
    );

    await tester.pumpWidget(_host(controller: controller, onRetry: () async {}));
    await tester.pumpAndSettle();

    expect(find.text('Active Vault'), findsOneWidget);
    expect(find.text('フォルダが見つかりません'), findsOneWidget);
    expect(find.text('場所を指定し直す'), findsOneWidget);
  });

  testWidgets('successful relink retries only after registry becomes available',
      (tester) async {
    var repaired = false;
    var retries = 0;
    final controller = VaultStartupRecoveryController(
      inspectRegistry: () async => [
        _location(
          repaired ? '/moved/active' : '/missing/active',
          repaired
              ? VaultAvailability.available
              : VaultAvailability.missingDirectory,
        ),
      ],
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => '/moved/active',
      ),
      relinkRegistry: ({required profileId, required directoryPath}) async {
        repaired = true;
        return _profile(directoryPath);
      },
      unregisterRegistryEntry: (_) async {},
    );

    await tester.pumpWidget(
      _host(
        controller: controller,
        onRetry: () async => retries += 1,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('場所を指定し直す'));
    await tester.pumpAndSettle();

    expect(repaired, isTrue);
    expect(retries, 1);
  });

  testWidgets('cancelled folder selection is a no-op and does not retry',
      (tester) async {
    var retries = 0;
    final controller = VaultStartupRecoveryController(
      inspectRegistry: () async => [
        _location('/missing/active', VaultAvailability.missingDirectory),
      ],
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      relinkRegistry: ({required profileId, required directoryPath}) async =>
          _profile(directoryPath),
      unregisterRegistryEntry: (_) async {},
    );

    await tester.pumpWidget(
      _host(
        controller: controller,
        onRetry: () async => retries += 1,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('場所を指定し直す'));
    await tester.pumpAndSettle();

    expect(retries, 0);
    expect(find.text('Active Vault'), findsOneWidget);
  });

  testWidgets('inspection failure stays privacy-safe and allows normal retry',
      (tester) async {
    var retries = 0;
    const secret = '/Users/private/secret-vault';
    final controller = VaultStartupRecoveryController(
      inspectRegistry: () async => throw StateError('broken at $secret'),
      directoryPicker: VaultDirectoryPickerService(
        directoryPicker: () async => null,
      ),
      relinkRegistry: ({required profileId, required directoryPath}) async =>
          _profile(directoryPath),
      unregisterRegistryEntry: (_) async {},
    );

    await tester.pumpWidget(
      _host(
        controller: controller,
        onRetry: () async => retries += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaultの復旧情報を読み込めませんでした。'), findsOneWidget);
    expect(find.textContaining(secret), findsNothing);
    await tester.tap(find.text('もう一度起動する'));
    await tester.pump();
    expect(retries, 1);
  });
}
