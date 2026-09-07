import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:bookmark_app/repositories/object_search_result_resolver.dart';
import 'package:bookmark_app/views/global_search_page.dart';
import 'package:bookmark_app/views/object_global_search_page.dart';
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

class _FakeSearchService extends ObjectGlobalSearchService {
  _FakeSearchService(
    GenericDatabaseStore store, {
    required this.onRebuild,
    required this.onSearch,
  }) : super(store);

  final Future<void> Function(int workspaceId) onRebuild;
  final Future<List<ResolvedObjectSearchHit>> Function(
    int workspaceId,
    String rawQuery,
    int? objectTypeId,
    int limit,
  ) onSearch;

  @override
  Future<void> rebuildWorkspace(int workspaceId) => onRebuild(workspaceId);

  @override
  Future<List<ResolvedObjectSearchHit>> search({
    required int workspaceId,
    required String rawQuery,
    int? objectTypeId,
    int limit = 100,
  }) =>
      onSearch(workspaceId, rawQuery, objectTypeId, limit);
}

class _RefreshFailingSearchService extends ObjectGlobalSearchService {
  _RefreshFailingSearchService(GenericDatabaseStore store) : super(store);

  @override
  Future<void> refreshVisitedDetailReturnObjects(
    Iterable<int> objectIds,
  ) async {
    final ids = objectIds.toList()..sort();
    throw StateError(
      'private refresh detail /Users/example/profile.db objects=$ids',
    );
  }
}

void main() {
  testWidgets('compatibility page routes to Object search and retries index failure',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    final genericStore = GenericDatabaseStore(database);
    var rebuildAttempts = 0;
    final searchService = _FakeSearchService(
      genericStore,
      onRebuild: (_) async {
        rebuildAttempts++;
        if (rebuildAttempts == 1) {
          throw StateError('private index detail /Users/example/profile.db');
        }
      },
      onSearch: (_, __, ___, ____) async => const <ResolvedObjectSearchHit>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          repository: repository,
          searchService: searchService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ObjectGlobalSearchPage), findsOneWidget);
    expect(rebuildAttempts, 1);
    expect(find.text('全文検索を準備できませんでした'), findsOneWidget);
    expect(
      find.text('検索インデックスを再構築して、もう一度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining('private index detail'), findsNothing);
    expect(find.textContaining('/Users/example/profile.db'), findsNothing);

    await tester.tap(find.text('検索インデックスを再構築'));
    await tester.pump();
    await tester.pump();

    expect(rebuildAttempts, 2);
    expect(find.text('オブジェクトを横断検索'), findsOneWidget);
    expect(find.text('ブックマークを横断検索'), findsNothing);
    expect(find.text('全文検索を準備できませんでした'), findsNothing);
  });

  testWidgets('Object query failure keeps stable retryable error boundary',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    final genericStore = GenericDatabaseStore(database);
    var rebuildAttempts = 0;
    var searchAttempts = 0;
    final searchService = _FakeSearchService(
      genericStore,
      onRebuild: (_) async {
        rebuildAttempts++;
      },
      onSearch: (_, __, ___, ____) async {
        searchAttempts++;
        throw StateError('private query detail token=should-not-render');
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          repository: repository,
          searchService: searchService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('オブジェクトを横断検索'), findsOneWidget);

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
    expect(find.text('オブジェクトを横断検索'), findsOneWidget);
    expect(find.text('全文検索を準備できませんでした'), findsNothing);
  });

  testWidgets('detail-return refresh failure keeps private errors out of UI',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Item',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'RefreshFailureToken',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectGlobalSearchPage(
          store: genericStore,
          workspaceId: workspaceId,
          searchService: _RefreshFailingSearchService(genericStore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'refreshfailure');
    await tester.pump(const Duration(milliseconds: 221));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('object-global-search-result-$objectId')),
    );
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('全文検索を準備できませんでした'), findsOneWidget);
    expect(
      find.text('検索インデックスを再構築して、もう一度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining('private refresh detail'), findsNothing);
    expect(find.textContaining('/Users/example/profile.db'), findsNothing);
  });
}