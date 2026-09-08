import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/views/app_shell.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets('shell exposes Images without legacy Photo navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final imageDefinition = await images.ensureDefinition(
      repository.workspaceId,
    );
    await objectStore.createObject(
      objectTypeId: imageDefinition.objectType.id,
      title: 'Command palette image',
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

    expect(find.text('写真'), findsNothing);
    expect(find.text('Images'), findsOneWidget);

    await tester.tap(find.byTooltip('サイドバーを閉じる'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    await tester.tap(find.byTooltip('サイドバーを開く'));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final searchField = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );

    await tester.enterText(searchField, '写真');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(ListTile, '写真'),
      ),
      findsNothing,
    );

    await tester.enterText(searchField, 'Images');
    await tester.pumpAndSettle();

    final imageDestination = find.descendant(
      of: dialog,
      matching: find.widgetWithText(ListTile, 'Images'),
    );
    expect(imageDestination, findsOneWidget);

    await tester.tap(imageDestination);
    await tester.pumpAndSettle();

    expect(find.byType(GenericDatabasePage), findsOneWidget);
    expect(find.text('Command palette image'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
