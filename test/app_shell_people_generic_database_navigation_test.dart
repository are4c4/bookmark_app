import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/views/app_shell.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:bookmark_app/views/people_management_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = DatabaseProfile(
  id: 'test-vault',
  name: 'Test Vault',
  databaseName: 'test.sqlite',
  directoryPath: '/tmp/test-vault',
);

const _profileState = ProfileState(
  profiles: <DatabaseProfile>[_profile],
  activeProfileId: 'test-vault',
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
  testWidgets('人物 shell destination opens canonical generic People Database', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    await PersonObjectWriteService.forDatabase(database).create(
      workspaceId: repository.workspaceId,
      name: 'Shell Person',
    );

    await tester.pumpWidget(_shell(repository));
    await tester.pumpAndSettle();

    expect(find.byType(PeopleManagementPage), findsNothing);

    await tester.tap(find.text('人物'));
    await tester.pumpAndSettle();

    expect(find.byType(GenericDatabasePage), findsOneWidget);
    expect(find.byType(PeopleManagementPage), findsNothing);
    expect(find.text('Shell Person'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
