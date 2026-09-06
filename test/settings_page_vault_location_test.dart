import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
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

Widget _page(
  BookmarkRepository repository, {
  Future<void> Function(String path)? revealVaultDirectory,
}) =>
    MaterialApp(
      home: SettingsPage(
        themeMode: ThemeMode.system,
        onThemeModeChanged: (_) {},
        repository: repository,
        revealVaultDirectory: revealVaultDirectory,
      ),
    );

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
}
