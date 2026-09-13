import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/build_provenance.dart';
import 'package:bookmark_app/views/app_build_info_section.dart';
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

void main() {
  testWidgets('Settings shows and copies installed build identity', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    String? copied;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          repository: repository,
          buildProvenance: const BuildProvenance(
            version: '0.1.0',
            buildNumber: '1',
            commitSha: 'db166afb0bf57fd75929ca02018b67c7d1802fe1',
            sourceState: 'dirty',
          ),
          copyBuildInfo: (text) async {
            copied = text;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('アプリ情報'), 240);

    expect(find.text('アプリ情報'), findsOneWidget);
    expect(find.textContaining('Version 0.1.0 (1)'), findsOneWidget);
    expect(find.textContaining('Commit db166af'), findsOneWidget);
    expect(find.textContaining('Source dirty'), findsOneWidget);

    final copyButton = find.descendant(
      of: find.byType(AppBuildInfoSection),
      matching: find.byType(OutlinedButton),
    );
    expect(copyButton, findsOneWidget);
    await tester.ensureVisible(copyButton);
    await tester.pumpAndSettle();
    await tester.tap(copyButton);
    await tester.pump();

    expect(copied, 'Bookmark 0.1.0 (1) · db166af · dirty');
    expect(find.text('ビルド情報をコピーしました。'), findsOneWidget);
  });
}
