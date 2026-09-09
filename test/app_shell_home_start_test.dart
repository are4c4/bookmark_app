import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/views/app_shell.dart';
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

void main() {
  testWidgets('starts on Home Recent while preserving transition navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final typeId = await objectStore.createObjectType(
      workspaceId: repository.workspaceId,
      name: 'Papers',
      icon: '📄',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Home recent paper',
    );

    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近のオブジェクト'), findsOneWidget);
    expect(
      find.byKey(ValueKey('home-recent-object-$objectId')),
      findsOneWidget,
    );
    expect(find.text('ブックマーク'), findsOneWidget);
    expect(find.text('人物'), findsOneWidget);
    expect(find.text('タグ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
