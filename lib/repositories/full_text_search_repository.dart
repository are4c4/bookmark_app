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

  Future<void> rebuild() async {
    await initialize();
    await _database.transaction(() async {
      await _database.customStatement('DELETE FROM bookmark_fts');
      await _database.customStatement('''
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
        WHERE b.storage_state != 'trash'
      ''');
    });
  }

  Future<void> refreshBookmark(int bookmarkId) async {
    await initialize();
    await _database.transaction(() async {
      await _database.customStatement(
        'DELETE FROM bookmark_fts WHERE bookmark_id = ?',
        [bookmarkId],
      );
      await _database.customStatement('''
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
        WHERE b.id = ? AND b.storage_state != 'trash'
      ''', [bookmarkId]);
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
