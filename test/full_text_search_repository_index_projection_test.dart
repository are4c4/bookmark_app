import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/full_text_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rebuild and focused refresh share the same searchable bookmark projection',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    final alphaId = await repository.create(
      url: 'https://example.com/alpha',
      title: 'Alpha Guide',
      tagNames: const ['Flutter'],
    );
    final betaId = await repository.create(
      url: 'https://example.com/beta',
      title: 'Beta Notes',
    );
    final search = FullTextSearchRepository(repository);

    await search.rebuild();

    expect(
      (await search.search('Alpha')).map((hit) => hit.bookmarkId),
      contains(alphaId),
    );
    expect(
      (await search.search('Beta')).map((hit) => hit.bookmarkId),
      contains(betaId),
    );
    expect(
      (await search.search('Flutter')).map((hit) => hit.bookmarkId),
      contains(alphaId),
    );

    await repository.update(
      id: alphaId,
      url: 'https://example.com/alpha',
      title: 'Gamma Guide',
      tagNames: const ['Dart'],
    );
    await search.refreshBookmark(alphaId);

    expect(await search.search('Flutter'), isEmpty);
    expect(
      (await search.search('Gamma')).map((hit) => hit.bookmarkId),
      contains(alphaId),
    );
    expect(
      (await search.search('Dart')).map((hit) => hit.bookmarkId),
      contains(alphaId),
    );
    expect(
      (await search.search('Beta')).map((hit) => hit.bookmarkId),
      contains(betaId),
    );
  });

  test('FTS bookmark projection SQL has a single implementation', () {
    final source = File(
      'lib/repositories/full_text_search_repository.dart',
    ).readAsStringSync();

    expect(
      RegExp(r'INSERT INTO bookmark_fts\(').allMatches(source),
      hasLength(1),
    );
    expect(source, contains('Future<void> _insertBookmarksIntoIndex'));
    expect(source, contains('await _insertBookmarksIntoIndex();'));
    expect(
      source,
      contains('await _insertBookmarksIntoIndex(bookmarkId: bookmarkId);'),
    );
  });
}
