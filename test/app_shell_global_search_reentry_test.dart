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

Finder _sidebarDestination(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    );

void main() {
  testWidgets(
      're-entering cached Global Search rebuilds after an external Object change',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    final store = GenericDatabaseStore(database);
    final objects = ObjectStore(store);
    final objectTypeId = await objects.createObjectType(
      workspaceId: repository.workspaceId,
      name: 'Shell Search Item',
    );
    final objectId = await objects.createObject(
      objectTypeId: objectTypeId,
      title: 'LegacyShellSearchToken',
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

    final searchDestination = _sidebarDestination('全文検索');
    expect(searchDestination, findsOneWidget);
    await tester.tap(searchDestination);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'legacyshellsearch');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('object-global-search-result-$objectId')),
      findsOneWidget,
    );

    final bookmarkDestination = _sidebarDestination('ブックマーク');
    expect(bookmarkDestination, findsOneWidget);
    await tester.tap(bookmarkDestination);
    await tester.pumpAndSettle();

    await objects.renameObject(objectId, 'CurrentShellSearchToken');

    await tester.tap(_sidebarDestination('全文検索'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-global-search-result-$objectId')),
      findsNothing,
      reason: 're-entering Search must rebuild away the stale old-title hit',
    );
    expect(find.text('一致するオブジェクトがありません'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'currentshellsearch');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('object-global-search-result-$objectId')),
      findsOneWidget,
      reason: 'the externally renamed Object must be searchable after re-entry',
    );

    // The shell caches its built destinations. Dispose the full tree explicitly
    // so cached page timers/controllers are cancelled before widget-test timer
    // invariants run, matching other real-host regressions in this repository.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // Drift closes watched queries through a zero-delay Timer after unmount.
    // Advance fake time once so StreamQueryStore can mark them closed before
    // the database teardown waits for those streams to finish.
    await tester.pump(const Duration(milliseconds: 1));
  });
}
