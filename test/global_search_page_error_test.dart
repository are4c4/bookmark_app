import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/global_search_page.dart';
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
  testWidgets('index failure hides raw exception text and retries successfully',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    var rebuildAttempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          repository: repository,
          rebuildSearchIndex: () async {
            rebuildAttempts++;
            if (rebuildAttempts == 1) {
              throw StateError('private index detail /Users/example/profile.db');
            }
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(rebuildAttempts, 1);
    expect(find.text('全文検索を準備できませんでした'), findsOneWidget);
    expect(
      find.text('検索処理で問題が発生しました。検索インデックスを再構築して、もう一度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining('private index detail'), findsNothing);
    expect(find.textContaining('/Users/example/profile.db'), findsNothing);

    await tester.tap(find.text('検索インデックスを再構築'));
    await tester.pump();
    await tester.pump();

    expect(rebuildAttempts, 2);
    expect(find.text('ブックマークを横断検索'), findsOneWidget);
    expect(find.text('全文検索を準備できませんでした'), findsNothing);
  });

  testWidgets('query failure uses the same stable retryable error boundary',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    var rebuildAttempts = 0;
    var searchAttempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          repository: repository,
          rebuildSearchIndex: () async {
            rebuildAttempts++;
          },
          searchBookmarks: (query, limit) async {
            searchAttempts++;
            throw StateError('private query detail token=should-not-render');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('ブックマークを横断検索'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'example');
    await tester.pump(const Duration(milliseconds: 221));
    await tester.pump();

    expect(searchAttempts, 1);
    expect(find.text('全文検索を準備できませんでした'), findsOneWidget);
    expect(find.textContaining('private query detail'), findsNothing);
    expect(find.textContaining('should-not-render'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 221));
    await tester.tap(find.text('検索インデックスを再構築'));
    await tester.pump();
    await tester.pump();

    expect(rebuildAttempts, 2);
    expect(find.text('ブックマークを横断検索'), findsOneWidget);
    expect(find.text('全文検索を準備できませんでした'), findsNothing);
  });
}
