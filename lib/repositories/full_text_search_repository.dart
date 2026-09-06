import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';

class BookmarkSearchHit {
  const BookmarkSearchHit({
    required this.bookmarkId,
    required this.rank,
    required this.snippet,
  });

  final int bookmarkId;
  final double rank;
  final String snippet;
}

String buildFtsPrefixQuery(String value) {
  final terms = value
      .trim()
      .split(RegExp(r'\s+'))
      .map((term) => term.replaceAll('"', '').trim())
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) return '';
  return terms.map((term) => '"$term"*').join(' AND ');
}

/// SQLite FTS5-backed search index for bookmark metadata and relations.
///
/// The index intentionally lives beside the Drift schema because FTS virtual
/// tables are search infrastructure rather than user-owned relational data.
class FullTextSearchRepository {
  FullTextSearchRepository(BookmarkRepository root)
      : _database = root.lifecycleStore.database;

  final AppDatabase _database;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _database.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS bookmark_fts USING fts5(
        bookmark_id UNINDEXED,
        title,
        url,
        description,
        tags,
        people,
        collections,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
    _initialized = true;
  }

  Future<void> _insertBookmarksIntoIndex({int? bookmarkId}) {
    final whereClause = bookmarkId == null
        ? "b.storage_state != 'trash'"
        : "b.id = ? AND b.storage_state != 'trash'";
    final arguments = bookmarkId == null
        ? const <Object?>[]
        : <Object?>[bookmarkId];
    return _database.customStatement('''
      INSERT INTO bookmark_fts(
        bookmark_id, title, url, description, tags, people, collections
      )
      SELECT
        b.id,
        b.title,
        b.url,
        COALESCE(b.description, ''),
        COALESCE((
          SELECT GROUP_CONCAT(t.name, ' ')
          FROM bookmark_tags bt
          JOIN tags t ON t.id = bt.tag_id
          WHERE bt.bookmark_id = b.id
        ), ''),
        COALESCE((
          SELECT GROUP_CONCAT(p.name || ' ' || bp.role, ' ')
          FROM bookmark_people bp
          JOIN people p ON p.id = bp.person_id
          WHERE bp.bookmark_id = b.id
        ), ''),
        COALESCE((
          SELECT GROUP_CONCAT(c.name, ' ')
          FROM bookmark_collections bc
          JOIN collections c ON c.id = bc.collection_id
          WHERE bc.bookmark_id = b.id
        ), '')
      FROM bookmarks b
      WHERE $whereClause
    ''', arguments);
  }

  Future<void> _deleteBookmarkFromIndex(int bookmarkId) async {
    // bookmark_id is intentionally UNINDEXED metadata. Resolve any matching
    // virtual-table rows first, then mutate FTS5 through its stable rowid so a
    // focused refresh cannot leave the old token stream behind. Reading every
    // matching rowid also cleans up accidental duplicate projections without
    // touching unrelated bookmarks.
    final rows = await _database.customSelect(
      '''
      SELECT rowid AS fts_rowid
      FROM bookmark_fts
      WHERE CAST(bookmark_id AS INTEGER) = ?
      ''',
      variables: [Variable<int>(bookmarkId)],
    ).get();
    for (final row in rows) {
      await _database.customStatement(
        'DELETE FROM bookmark_fts WHERE rowid = ?',
        [row.read<int>('fts_rowid')],
      );
    }
  }

  Future<void> rebuild() async {
    await initialize();
    await _database.transaction(() async {
      await _database.customStatement('DELETE FROM bookmark_fts');
      await _insertBookmarksIntoIndex();
    });
  }

  Future<void> refreshBookmark(int bookmarkId) async {
    await initialize();
    await _database.transaction(() async {
      await _deleteBookmarkFromIndex(bookmarkId);
      await _insertBookmarksIntoIndex(bookmarkId: bookmarkId);
    });
  }

  Future<List<BookmarkSearchHit>> search(String rawQuery, {int limit = 100}) async {
    await initialize();
    final query = buildFtsPrefixQuery(rawQuery);
    if (query.isEmpty) return const [];

    final rows = await _database.customSelect(
      '''
      SELECT
        CAST(bookmark_id AS INTEGER) AS bookmark_id,
        bm25(bookmark_fts, 0.0, 5.0, 2.5, 1.5, 1.2, 1.2, 1.0) AS rank,
        snippet(bookmark_fts, 3, '‹', '›', ' … ', 20) AS snippet
      FROM bookmark_fts
      WHERE bookmark_fts MATCH ?
      ORDER BY rank
      LIMIT ?
      ''',
      variables: [Variable.withString(query), Variable.withInt(limit)],
    ).get();

    return rows
        .map(
          (row) => BookmarkSearchHit(
            bookmarkId: row.read<int>('bookmark_id'),
            rank: row.read<double>('rank'),
            snippet: row.read<String>('snippet'),
          ),
        )
        .toList();
  }
}
