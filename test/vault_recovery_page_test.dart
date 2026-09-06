import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_availability_service.dart';
import 'package:bookmark_app/services/vault_registry_inspection_service.dart';
import 'package:bookmark_app/views/vault_recovery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

VaultRegistryLocation _location({
  required String id,
  required String name,
  required String path,
  required VaultAvailability availability,
  bool active = false,
}) =>
    VaultRegistryLocation(
      profile: DatabaseProfile(
        id: id,
        name: name,
        databaseName: 'BookmarkApp/Profiles/$id/database',
        directoryPath: path,
      ),
      availability: availability,
      isActive: active,
    );

Widget _host({
  required List<VaultRegistryLocation> locations,
  required Future<void> Function(VaultRegistryLocation) onRelink,
  Future<void> Function(VaultRegistryLocation)? onUnregister,
  VoidCallback? onRetry,
}) =>
    MaterialApp(
      home: VaultRecoveryPage(
        locations: locations,
        onRelink: onRelink,
        onUnregisterInactive: onUnregister,
        onRetry: onRetry,
      ),
    );

void main() {
  testWidgets('shows only unavailable Vaults and distinguishes failure reason',
      (tester) async {
    await tester.pumpWidget(
      _host(
        locations: [
          _location(
            id: 'active',
            name: 'Active Missing',
            path: '/Volumes/Drive/Active',
            availability: VaultAvailability.missingDirectory,
            active: true,
          ),
          _location(
            id: 'no-db',
            name: 'No Database',
            path: '/Volumes/Drive/NoDb',
            availability: VaultAvailability.missingDatabase,
          ),
          _location(
            id: 'ok',
            name: 'Available Vault',
            path: '/tmp/Available',
            availability: VaultAvailability.available,
          ),
        ],
        onRelink: (_) async {},
      ),
    );

    expect(find.text('Active Missing'), findsOneWidget);
    expect(find.text('フォルダが見つかりません'), findsOneWidget);
    expect(find.text('現在のVault'), findsOneWidget);
    expect(find.text('No Database'), findsOneWidget);
    expect(find.text('database.sqlite が見つかりません'), findsOneWidget);
    expect(find.text('Available Vault'), findsNothing);
    expect(find.text('場所を指定し直す'), findsNWidgets(2));
  });

  testWidgets('active Vault never exposes unregister action', (tester) async {
    await tester.pumpWidget(
      _host(
        locations: [
          _location(
            id: 'active',
            name: 'Active',
            path: '/missing/active',
            availability: VaultAvailability.missingDirectory,
            active: true,
          ),
        ],
        onRelink: (_) async {},
        onUnregister: (_) async {},
      ),
    );

    expect(find.text('登録から外す'), findsNothing);
  });

  testWidgets('inactive unregister requires confirmation and delegates once',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        locations: [
          _location(
            id: 'inactive',
            name: 'Offline Archive',
            path: '/Volumes/Archive/Offline',
            availability: VaultAvailability.missingDirectory,
          ),
        ],
        onRelink: (_) async {},
        onUnregister: (_) async => calls += 1,
      ),
    );

    await tester.tap(find.text('登録から外す'));
    await tester.pumpAndSettle();
    expect(find.text('「Offline Archive」を登録から外しますか？'), findsOneWidget);
    expect(find.textContaining('フォルダやファイルは削除しません'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '登録から外す'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('relink failures show a generic message without exception details',
      (tester) async {
    const secret = '/Users/private/secret-vault';
    await tester.pumpWidget(
      _host(
        locations: [
          _location(
            id: 'missing',
            name: 'Missing',
            path: '/missing/registered',
            availability: VaultAvailability.missingDirectory,
            active: true,
          ),
        ],
        onRelink: (_) async => throw StateError('failed at $secret'),
      ),
    );

    await tester.tap(find.text('場所を指定し直す'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vaultの保存場所を更新できませんでした'), findsOneWidget);
    expect(find.textContaining(secret), findsNothing);
  });

  testWidgets('empty recovery set can retry normal startup', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(
        locations: const [],
        onRelink: (_) async {},
        onRetry: () => retries += 1,
      ),
    );

    expect(find.textContaining('再接続が必要なVaultは見つかりませんでした'), findsOneWidget);
    await tester.tap(find.text('もう一度起動する'));
    expect(retries, 1);
  });
}
