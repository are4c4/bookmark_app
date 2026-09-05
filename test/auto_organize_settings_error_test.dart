import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/auto_organize_service.dart';
import 'package:bookmark_app/views/auto_organize_settings_section.dart';
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

Widget _section(
  BookmarkRepository repository, {
  AutoOrganizeRuleCreator? createRule,
  AutoOrganizeRunner? runAll,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: AutoOrganizeSettingsSection(
            repository: repository,
            loadRules: () async => const <AutoOrganizeRule>[],
            createRule: createRule,
            runAll: runAll,
          ),
        ),
      ),
    );

void main() {
  testWidgets('rule creation failure hides raw implementation details',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    String? submittedName;
    String? submittedKeyword;
    String? submittedTag;

    await tester.pumpWidget(
      _section(
        repository,
        createRule: ({
          required String name,
          required AutoOrganizeMatchField matchField,
          required String keyword,
          required String tagName,
          required String genre,
        }) async {
          submittedName = name;
          submittedKeyword = keyword;
          submittedTag = tagName;
          throw StateError('private rule SQL detail token=should-not-render');
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('ルール追加'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), 'YouTube');
    await tester.enterText(fields.at(1), 'youtube.com');
    await tester.enterText(fields.at(2), '動画');
    await tester.tap(find.text('追加'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(submittedName, 'YouTube');
    expect(submittedKeyword, 'youtube.com');
    expect(submittedTag, '動画');
    expect(
      find.text('ルールを保存できませんでした。入力内容を確認して、もう一度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining('private rule SQL detail'), findsNothing);
    expect(find.textContaining('should-not-render'), findsNothing);
  });

  testWidgets('bulk application failure hides raw implementation details',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    var runAttempts = 0;

    await tester.pumpWidget(
      _section(
        repository,
        runAll: () async {
          runAttempts++;
          throw StateError('private bulk detail /Users/example/database.sqlite');
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('既存データに適用'));
    await tester.pump();
    await tester.pump();

    expect(runAttempts, 1);
    expect(
      find.text('自動整理を実行できませんでした。もう一度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining('private bulk detail'), findsNothing);
    expect(find.textContaining('/Users/example/database.sqlite'), findsNothing);
  });
}
