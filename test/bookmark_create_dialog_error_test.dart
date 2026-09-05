import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/widgets/bookmark_create_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkLifecycleStore lifecycleStore;
  late BookmarkRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
      profileDirectoryPath: '/tmp/bookmark-create-error-test',
    );
  });

  tearDown(() async {
    await lifecycleStore.dispose();
    await database.close();
  });

  testWidgets('URL creation failure hides raw implementation details',
      (tester) async {
    var fetchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showBookmarkCreateDialog(
                  context: context,
                  repository: repository,
                  fetchMetadata: (_) async {
                    fetchCalls++;
                    throw StateError(
                      'metadata-secret:https://private.example/token',
                    );
                  },
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'https://example.com');
    await tester.tap(find.text('URLから追加'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fetchCalls, 1);
    expect(
      find.text('ブックマークを追加できませんでした。もう一度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining('metadata-secret'), findsNothing);
    expect(find.textContaining('private.example'), findsNothing);
    expect(find.text('ブックマークを追加'), findsOneWidget);
  });

  test('file creation failure uses a stable privacy-safe boundary', () {
    final source = File('lib/widgets/bookmark_create_dialog.dart')
        .readAsStringSync();

    expect(source, contains("_debugFailure('file bookmark creation', stackTrace)"));
    expect(
      source,
      contains('ファイルから作成できませんでした。もう一度お試しください。'),
    );
    expect(source, isNot(contains('ファイルから作成できませんでした:')));
    expect(source, isNot(contains('ブックマークを追加できませんでした:')));
  });
}
