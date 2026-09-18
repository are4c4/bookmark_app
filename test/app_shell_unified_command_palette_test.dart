import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/views/app_shell.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = DatabaseProfile(
  id: 'command-palette-test-vault',
  name: 'Command Palette Test Vault',
  databaseName: 'test.sqlite',
  directoryPath: '/tmp/command-palette-test-vault',
);

const _profileState = ProfileState(
  profiles: <DatabaseProfile>[_profile],
  activeProfileId: 'command-palette-test-vault',
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

  testWidgets('⌘K prepares Search on first use and opens a canonical Object', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final weblinks = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final created = await weblinks.findOrCreate(
      workspaceId: repository.workspaceId,
      url: 'https://example.com/command-palette-object',
      title: 'Unique command palette article',
    );
    final objectId = created.id;
    expect(
      await ObjectSearchRepository(genericStore).search(
        workspaceId: repository.workspaceId,
        rawQuery: 'Unique command palette',
      ),
      isEmpty,
      reason: 'precondition: the palette starts from an unprepared index',
    );

    await tester.pumpWidget(_shell(repository));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    final query = find.byKey(
      const ValueKey<String>('unified-command-palette-query'),
    );
    expect(query, findsOneWidget);

    await tester.enterText(query, 'Unique command palette');
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pumpAndSettle();

    final objectResult = find.byKey(
      ValueKey<String>('unified-command-palette-item-object:$objectId'),
    );
    expect(objectResult, findsOneWidget);

    await tester.tap(objectResult);
    await tester.pumpAndSettle();

    expect(find.text('Unique command palette article'), findsWidgets);
    expect(find.text('コマンドパレット'), findsNothing);
  });

  testWidgets('empty ⌘K surfaces canonical Recent and opens its Object', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final weblinks = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    await tester.pumpWidget(_shell(repository));
    await tester.pumpAndSettle();

    final created = await weblinks.findOrCreate(
      workspaceId: repository.workspaceId,
      url: 'https://example.com/recent-command-palette-object',
      title: 'Recently changed command palette article',
    );
    await database.customStatement(
      "UPDATE generic_records SET updated_at = '2099-01-01 00:00:00' WHERE id = ?",
      [created.id],
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    final recentResult = find.byKey(
      ValueKey<String>(
        'unified-command-palette-item-recent-object:${created.id}',
      ),
    );
    final paletteList = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ListView),
    );
    expect(paletteList, findsOneWidget);
    await tester.drag(paletteList, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('最近のオブジェクト'),
      ),
      findsOneWidget,
    );
    expect(recentResult, findsOneWidget);

    await tester.tap(recentResult);
    await tester.pumpAndSettle();

    expect(find.text('Recently changed command palette article'), findsWidgets);
    expect(find.text('コマンドパレット'), findsNothing);
  });
}
