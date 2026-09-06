import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/services/vault_lifecycle_scope.dart';
import 'package:bookmark_app/views/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BookmarkRepository> _repository(
  AppDatabase database, {
  required String profileDirectoryPath,
}) async {
  final workspaceStore = WorkspaceStore(database);
  final workspaceId = await workspaceStore.initialize();
  final lifecycleStore = BookmarkLifecycleStore(database);
  await lifecycleStore.initialize();
  return BookmarkRepository(
    database,
    workspaceStore: workspaceStore,
    lifecycleStore: lifecycleStore,
    workspaceId: workspaceId,
    profileDirectoryPath: profileDirectoryPath,
  );
}

DatabaseProfile _profile(String id, String name, String path) => DatabaseProfile(
      id: id,
      name: name,
      databaseName: '$id-db',
      directoryPath: path,
    );

Widget _page(
  BookmarkRepository repository, {
  Future<void> Function(String path)? revealVaultDirectory,
  ProfileState? vaultState,
  Future<void> Function()? createVault,
  Future<void> Function()? openVault,
  Future<void> Function(DatabaseProfile profile)? switchVault,
  Future<void> Function()? moveVault,
}) {
  Widget child = SettingsPage(
    themeMode: ThemeMode.system,
    onThemeModeChanged: (_) {},
    repository: repository,
    revealVaultDirectory: revealVaultDirectory,
  );
  if (vaultState != null) {
    child = VaultLifecycleScope(
      profileState: vaultState,
      createVault: createVault ?? () async {},
      openVault: openVault ?? () async {},
      switchVault: switchVault ?? (_) async {},
      moveVault: moveVault,
      child: child,
    );
  }
  return MaterialApp(home: child);
}

void main() {
  testWidgets('settings shows active Vault folder and path', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const vaultPath = '/Users/example/Documents/My Vault';
    final repository = await _repository(
      database,
      profileDirectoryPath: vaultPath,
    );
    String? revealedPath;

    await tester.pumpWidget(
      _page(
        repository,
        revealVaultDirectory: (path) async {
          revealedPath = path;
        },
      ),
    );
    await tester.pump();

    expect(find.text('データ保管庫 (Vault)'), findsOneWidget);
    expect(find.text('My Vault'), findsOneWidget);
    expect(find.text(vaultPath), findsOneWidget);

    final revealButton = find.text('Finderで表示');
    await tester.ensureVisible(revealButton);
    await tester.tap(revealButton);
    await tester.pump();

    expect(revealedPath, vaultPath);
  });

  testWidgets('Finder reveal failure hides raw filesystem details', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const vaultPath = '/Users/example/private/Vault';
    final repository = await _repository(
      database,
      profileDirectoryPath: vaultPath,
    );

    await tester.pumpWidget(
      _page(
        repository,
        revealVaultDirectory: (_) async {
          throw StateError('private Finder detail: $vaultPath');
        },
      ),
    );
    await tester.pump();

    final revealButton = find.text('Finderで表示');
    await tester.ensureVisible(revealButton);
    await tester.tap(revealButton);
    await tester.pump();

    expect(
      find.text('VaultをFinderで表示できませんでした。保存場所を確認してください。'),
      findsOneWidget,
    );
    expect(find.textContaining('private Finder detail'), findsNothing);
  });

  testWidgets('Vault lifecycle scope wires create, open, switch, and move actions',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const vaultPath = '/Users/example/Documents/Current Vault';
    final repository = await _repository(
      database,
      profileDirectoryPath: vaultPath,
    );
    final current = _profile('current', 'Current Vault', vaultPath);
    final other = _profile('other', 'Other Vault', '/Volumes/Data/Other Vault');
    final state = ProfileState(
      profiles: [current, other],
      activeProfileId: current.id,
    );
    var createCount = 0;
    var openCount = 0;
    var moveCount = 0;
    String? switchedId;

    await tester.pumpWidget(
      _page(
        repository,
        vaultState: state,
        createVault: () async => createCount++,
        openVault: () async => openCount++,
        switchVault: (profile) async => switchedId = profile.id,
        moveVault: () async => moveCount++,
      ),
    );
    await tester.pump();

    final createButton = find.text('新しいVaultを作成');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();
    expect(createCount, 1);

    final openButton = find.text('既存のVaultを開く');
    await tester.ensureVisible(openButton);
    await tester.tap(openButton);
    await tester.pump();
    expect(openCount, 1);

    final switchButton = find.text('Vaultを切り替える');
    await tester.ensureVisible(switchButton);
    await tester.tap(switchButton);
    await tester.pumpAndSettle();
    expect(find.text('Other Vault'), findsOneWidget);

    await tester.tap(find.text('Other Vault'));
    await tester.pumpAndSettle();
    expect(switchedId, 'other');

    final moveButton = find.text('Vaultを移動');
    await tester.ensureVisible(moveButton);
    await tester.tap(moveButton);
    await tester.pump();
    expect(moveCount, 1);
  });

  testWidgets('Vault action failure hides raw filesystem exception details',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const vaultPath = '/Users/example/Documents/Current Vault';
    final repository = await _repository(
      database,
      profileDirectoryPath: vaultPath,
    );
    final current = _profile('current', 'Current Vault', vaultPath);

    await tester.pumpWidget(
      _page(
        repository,
        vaultState: ProfileState(
          profiles: [current],
          activeProfileId: current.id,
        ),
        createVault: () async {
          throw StateError('private path: /Users/example/Secret');
        },
      ),
    );
    await tester.pump();

    final createButton = find.text('新しいVaultを作成');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();

    expect(
      find.text('新しいVaultを作成できませんでした。現在のVaultは変更されていません。'),
      findsOneWidget,
    );
    expect(find.textContaining('/Users/example/Secret'), findsNothing);
  });

  testWidgets('Vault move failure hides raw path and states source is retained',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const vaultPath = '/Users/example/Documents/Current Vault';
    final repository = await _repository(
      database,
      profileDirectoryPath: vaultPath,
    );
    final current = _profile('current', 'Current Vault', vaultPath);

    await tester.pumpWidget(
      _page(
        repository,
        vaultState: ProfileState(
          profiles: [current],
          activeProfileId: current.id,
        ),
        moveVault: () async {
          throw StateError('target failed: /Users/example/PrivateTarget');
        },
      ),
    );
    await tester.pump();

    final moveButton = find.text('Vaultを移動');
    await tester.ensureVisible(moveButton);
    await tester.tap(moveButton);
    await tester.pump();

    expect(
      find.text('Vaultを移動できませんでした。移動元のVaultは削除されていません。'),
      findsOneWidget,
    );
    expect(find.textContaining('/Users/example/PrivateTarget'), findsNothing);
  });
}
