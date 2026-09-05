import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget _page(
  BookmarkRepository repository, {
  Future<String?> Function()? exportBackupFile,
  Future<String?> Function()? chooseBackupFile,
  Future<void> Function(String path)? restoreBackupFile,
}) =>
    MaterialApp(
      home: SettingsPage(
        themeMode: ThemeMode.system,
        onThemeModeChanged: (_) {},
        repository: repository,
        exportBackupFile: exportBackupFile,
        chooseBackupFile: chooseBackupFile,
        restoreBackupFile: restoreBackupFile,
      ),
    );

void main() {
  testWidgets('backup export failure hides raw implementation details',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);

    await tester.pumpWidget(
      _page(
        repository,
        exportBackupFile: () async {
          throw StateError('private export path /Users/example/backup.json');
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('バックアップを書き出す'));
    await tester.pump();

    expect(
      find.text('バックアップを作成できませんでした。もう一度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining('private export path'), findsNothing);
    expect(find.textContaining('/Users/example/backup.json'), findsNothing);
  });

  testWidgets('backup restore keeps confirmation and hides raw failure details',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    String? restoredPath;

    await tester.pumpWidget(
      _page(
        repository,
        chooseBackupFile: () async => '/Users/example/private-backup.json',
        restoreBackupFile: (path) async {
          restoredPath = path;
          throw StateError('private restore detail path=$path');
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('バックアップから復元'));
    await tester.pump();
    await tester.pump();

    expect(find.text('バックアップから復元しますか？'), findsOneWidget);
    expect(restoredPath, isNull);

    await tester.tap(find.text('復元'));
    await tester.pump();
    await tester.pump();

    expect(restoredPath, '/Users/example/private-backup.json');
    expect(
      find.text('バックアップを復元できませんでした。ファイルを確認して、もう一度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining('private restore detail'), findsNothing);
    expect(find.textContaining('/Users/example/private-backup.json'), findsNothing);
  });
}
