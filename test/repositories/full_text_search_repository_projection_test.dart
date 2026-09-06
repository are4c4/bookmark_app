import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/full_text_search_repository.dart';
import 'package:drift/drift.dart';
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
      title: 'LegacyHeading Guide',
      tagNames: const ['Flutter'],
    );
    final betaId = await repository.create(
      url: 'https://example.com/beta',
      title: 'Beta Notes',
    );
    final search = FullTextSearchRepository(repository);

    await search.rebuild();

    expect(
      (await search.search('LegacyHeading')).map((hit) => hit.bookmarkId),
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
      title: 'CurrentHeading Guide',
      tagNames: const ['Dart'],
    );
    await search.refreshBookmark(alphaId);

    final focusedRows = await database.customSelect(
      '''
      SELECT rowid AS fts_rowid,
             CAST(bookmark_id AS INTEGER) AS bookmark_id,
             title,
             tags
      FROM bookmark_fts
      WHERE CAST(bookmark_id AS INTEGER) = ?
      ORDER BY rowid
      ''',
      variables: [Variable<int>(alphaId)],
    ).get();
    final focusedProjection = focusedRows
        .map(
          (row) => <Object?>[
            row.read<int>('fts_rowid'),
            row.read<int>('bookmark_id'),
            row.read<String>('title'),
            row.read<String>('tags'),
          ],
        )
        .toList(growable: false);
    expect(
      focusedProjection,
      [
        [anything, alphaId, 'CurrentHeading Guide', 'Dart'],
      ],
      reason: 'focused refresh must replace stored FTS content exactly once',
    );

    final staleRows = await database.customSelect(
      '''
      SELECT rowid AS fts_rowid,
             CAST(bookmark_id AS INTEGER) AS bookmark_id,
             title,
             tags
      FROM bookmark_fts
      WHERE bookmark_fts MATCH ?
      ORDER BY rowid
      ''',
      variables: [
        Variable<String>(buildFtsPrefixQuery('LegacyHeading')),
      ],
    ).get();
    final staleProjection = staleRows
        .map(
          (row) => <Object?>[
            row.read<int>('fts_rowid'),
            row.read<int>('bookmark_id'),
            row.read<String>('title'),
            row.read<String>('tags'),
          ],
        )
        .toList(growable: false);
    expect(
      staleProjection,
      isEmpty,
      reason:
          'MATCH must not retain stale title postings after stored FTS content changes',
    );

    expect(
      (await search.search('CurrentHeading')).map((hit) => hit.bookmarkId),
      contains(alphaId),
    );
    expect(
      (await search.search('Dart')).map((hit) => hit.bookmarkId),
      contains(alphaId),
    );
    expect(
      (await search.search('LegacyHeading')).map((hit) => hit.bookmarkId),
      isNot(contains(alphaId)),
      reason: 'focused refresh must remove stale title tokens',
    );
    expect(
      (await search.search('Flutter')).map((hit) => hit.bookmarkId),
      isNot(contains(alphaId)),
      reason: 'focused refresh must remove stale relation/tag tokens',
    );
    expect(
      (await search.search('Beta')).map((hit) => hit.bookmarkId),
      contains(betaId),
      reason: 'focused refresh must not rebuild or remove unrelated entries',
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
