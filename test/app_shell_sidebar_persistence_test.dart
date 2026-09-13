import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/views/app_shell.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = DatabaseProfile(
  id: 'sidebar-test-vault',
  name: 'Sidebar Test Vault',
  databaseName: 'test.sqlite',
  directoryPath: '/tmp/sidebar-test-vault',
);

const _profileState = ProfileState(
  profiles: <DatabaseProfile>[_profile],
  activeProfileId: 'sidebar-test-vault',
);

Future<BookmarkRepository> _repository(AppDatabase database) async {
  final workspaceStore = WorkspaceStore(database);
  final workspaceId = await workspaceStore.initialize();
  final lifecycleStore = BookmarkLifecycleStore(database);
  await lifecycleStore.initialize();
  return BookmarkRepository(
    database,
    workspaceStore: workspaceStore,
    lifecycleStore: lifecycleStore,
    workspaceId: workspaceId,
  );
}

Widget _shell(BookmarkRepository repository) => MaterialApp(
  home: BookmarkAppShell(
    repository: repository,
    profileState: _profileState,
    themeMode: ThemeMode.light,
    onThemeModeChanged: (_) {},
    onSwitchProfile: (_) async {},
    onCreateProfile: (_) async {},
    onRenameProfile: (_, __) async {},
    onDuplicateProfile: (_) async {},
    onImportProfileBackup: (_, __) async {},
    onDeleteProfile: (_) async {},
    onSwitchWorkspace: (_) async {},
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('sidebar collapsed state survives shell recreation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);

    await tester.pumpWidget(_shell(repository));
    await tester.pumpAndSettle();
    expect(find.byTooltip('サイドバーを閉じる'), findsOneWidget);

    await tester.tap(find.byTooltip('サイドバーを閉じる'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('サイドバーを開く'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_shell(repository));
    await tester.pumpAndSettle();
    expect(find.byTooltip('サイドバーを開く'), findsOneWidget);

    await tester.tap(find.byTooltip('サイドバーを開く'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_shell(repository));
    await tester.pumpAndSettle();
    expect(find.byTooltip('サイドバーを閉じる'), findsOneWidget);
  });

  testWidgets('malformed sidebar preference falls back to expanded', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ui.layout.sidebarCollapsed.v1': 'old-format',
    });
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);

    await tester.pumpWidget(_shell(repository));
    await tester.pumpAndSettle();

    expect(find.byTooltip('サイドバーを閉じる'), findsOneWidget);
    expect(find.byTooltip('サイドバーを開く'), findsNothing);
  });
}
