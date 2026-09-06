import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/generic_database_store.dart';
import '../data/object_alias_store.dart';

class ObjectSearchHit {
  const ObjectSearchHit({
    required this.objectId,
    required this.objectTypeId,
    required this.workspaceId,
    required this.rank,
    required this.snippet,
  });

  final int objectId;
  final int objectTypeId;
  final int workspaceId;
  final double rank;
  final String snippet;
}

/// Canonical FTS5 index for Object-level search.
///
/// The first production slice indexes Object titles and aliases. The remaining
/// text buckets are present from the start so Properties, Body, Relation
/// labels, Weblink metadata, and derived File text can join the same projection
/// instead of creating domain-specific search products.
class ObjectSearchRepository {
  ObjectSearchRepository(GenericDatabaseStore genericStore)
      : _genericStore = genericStore,
        _database = genericStore.database,
        _aliasStore = ObjectAliasStore(genericStore);

  final GenericDatabaseStore _genericStore;
  final AppDatabase _database;
  final ObjectAliasStore _aliasStore;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _genericStore.ensureSchema();
    await _aliasStore.ensureSchema();
    await _database.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS object_search_fts USING fts5(
        object_id UNINDEXED,
        object_type_id UNINDEXED,
        workspace_id UNINDEXED,
        title,
        aliases,
        properties,
        body,
        relation_labels,
        weblink_metadata,
        derived_text,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
    _initialized = true;
  }

  String _buildPrefixQuery(String value) {
    final terms = value
        .trim()
        .split(RegExp(r'\s+'))
        .map((term) => term.replaceAll('"', '').trim())
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty) return '';
    return terms.map((term) => '"$term"*').join(' AND ');
  }

  Future<void> _insertObjects({
    int? workspaceId,
    int? objectId,
  }) {
    if (workspaceId == null && objectId == null) {
      throw ArgumentError('Object search projection insert requires a scope.');
    }
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (workspaceId != null) {
      conditions.add('d.workspace_id = ?');
      arguments.add(workspaceId);
    }
    if (objectId != null) {
      conditions.add('r.id = ?');
      arguments.add(objectId);
    }
    return _database.customStatement('''
      INSERT INTO object_search_fts(
        object_id,
        object_type_id,
        workspace_id,
        title,
        aliases,
        properties,
        body,
        relation_labels,
        weblink_metadata,
        derived_text
      )
      SELECT
        r.id,
        r.database_id,
        d.workspace_id,
        r.title,
        COALESCE((
          SELECT GROUP_CONCAT(ordered_aliases.alias, ' ')
          FROM (
            SELECT a.alias
            FROM object_aliases a
            WHERE a.object_id = r.id
            ORDER BY a.position, a.normalized_alias
          ) AS ordered_aliases
        ), ''),
        '',
        '',
        '',
        '',
        ''
      FROM generic_records r
      JOIN generic_databases d ON d.id = r.database_id
      WHERE ${conditions.join(' AND ')}
    ''', arguments);
  }

  Future<List<int>> _matchingRowIds({
    int? workspaceId,
    int? objectId,
  }) async {
    if (workspaceId == null && objectId == null) {
      throw ArgumentError('Object search row lookup requires a scope.');
    }
    final conditions = <String>[];
    final variables = <Variable<Object>>[];
    if (workspaceId != null) {
      conditions.add('CAST(workspace_id AS INTEGER) = ?');
      variables.add(Variable<int>(workspaceId));
    }
    if (objectId != null) {
      conditions.add('CAST(object_id AS INTEGER) = ?');
      variables.add(Variable<int>(objectId));
    }
    final rows = await _database.customSelect(
      '''SELECT rowid AS fts_rowid
         FROM object_search_fts
         WHERE ${conditions.join(' AND ')}''',
      variables: variables,
    ).get();
    return rows
        .map((row) => row.read<int>('fts_rowid'))
        .toList(growable: false);
  }

  Future<void> _deleteRows(Iterable<int> rowIds) async {
    for (final rowId in rowIds) {
      await _database.customStatement(
        'DELETE FROM object_search_fts WHERE rowid = ?',
        [rowId],
      );
    }
  }

  /// Rebuilds only one workspace, leaving indexed Objects in other workspaces
  /// untouched.
  Future<void> rebuildWorkspace(int workspaceId) async {
    await initialize();
    await _database.transaction(() async {
      await _deleteRows(await _matchingRowIds(workspaceId: workspaceId));
      await _insertObjects(workspaceId: workspaceId);
    });
  }

  /// Refreshes one canonical Object projection by identity alone. A deleted
  /// Object is naturally removed because the focused INSERT SELECT yields no
  /// row, and callers cannot accidentally supply a mismatched workspace.
  Future<void> refreshObject(int objectId) async {
    await initialize();
    await _database.transaction(() async {
      await _deleteRows(await _matchingRowIds(objectId: objectId));
      await _insertObjects(objectId: objectId);
    });
  }

  Future<List<ObjectSearchHit>> search({
    required int workspaceId,
    required String rawQuery,
    int? objectTypeId,
    int limit = 100,
  }) async {
    await initialize();
    final query = _buildPrefixQuery(rawQuery);
    if (query.isEmpty) return const <ObjectSearchHit>[];

    final typeClause = objectTypeId == null
        ? ''
        : 'AND CAST(object_type_id AS INTEGER) = ?';
    final variables = <Variable<Object>>[
      Variable<String>(query),
      Variable<int>(workspaceId),
      if (objectTypeId != null) Variable<int>(objectTypeId),
      Variable<int>(limit),
    ];
    final rows = await _database.customSelect(
      '''
      SELECT
        CAST(object_id AS INTEGER) AS object_id,
        CAST(object_type_id AS INTEGER) AS object_type_id,
        CAST(workspace_id AS INTEGER) AS workspace_id,
        bm25(object_search_fts) AS rank,
        snippet(object_search_fts, -1, '‹', '›', ' … ', 20) AS snippet
      FROM object_search_fts
      WHERE object_search_fts MATCH ?
        AND CAST(workspace_id AS INTEGER) = ?
        $typeClause
      ORDER BY rank, object_id
      LIMIT ?
      ''',
      variables: variables,
    ).get();

    return rows
        .map(
          (row) => ObjectSearchHit(
            objectId: row.read<int>('object_id'),
            objectTypeId: row.read<int>('object_type_id'),
            workspaceId: row.read<int>('workspace_id'),
            rank: row.read<double>('rank'),
            snippet: row.read<String>('snippet'),
          ),
        )
        .toList(growable: false);
  }
}
