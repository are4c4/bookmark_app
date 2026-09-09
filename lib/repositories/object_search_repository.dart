import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/generic_database_store.dart';
import '../data/object_alias_store.dart';
import '../data/object_body_store.dart';
import '../data/object_store.dart';
import '../data/relation_read_service.dart';
import '../data/relation_stored_value_inspector.dart';
import '../data/system_object_store.dart';
import '../data/weblink_object_service.dart';
import '../domain/object_model.dart';
import 'object_body_search_text.dart';
import 'object_derived_search_text_store.dart';
import 'object_property_search_text.dart';
import 'object_relation_search_text.dart';
import 'object_search_width_compatibility.dart';
import 'weblink_search_text.dart';

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
/// All ObjectTypes share one projection. Domain- and capability-specific
/// sources contribute user-facing text to dedicated buckets rather than
/// creating parallel search products.
class ObjectSearchRepository {
  ObjectSearchRepository(GenericDatabaseStore genericStore)
      : _genericStore = genericStore,
        _database = genericStore.database,
        _aliasStore = ObjectAliasStore(genericStore),
        _bodyStore = ObjectBodyStore(genericStore),
        _derivedTextStore = ObjectDerivedSearchTextStore(genericStore),
        _objectStore = ObjectStore(genericStore),
        _relationReads = RelationReadService(ObjectStore(genericStore)),
        _systemObjects = SystemObjectStore(
          database: genericStore.database,
          objectStore: ObjectStore(genericStore),
        );

  static const List<String> _searchTextColumns = <String>[
    'title',
    'aliases',
    'properties',
    'body',
    'relation_labels',
    'weblink_metadata',
    'derived_text',
  ];

  final GenericDatabaseStore _genericStore;
  final AppDatabase _database;
  final ObjectAliasStore _aliasStore;
  final ObjectBodyStore _bodyStore;
  final ObjectDerivedSearchTextStore _derivedTextStore;
  final ObjectStore _objectStore;
  final RelationReadService _relationReads;
  final SystemObjectStore _systemObjects;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _genericStore.ensureSchema();
    await _aliasStore.ensureSchema();
    await _bodyStore.ensureSchema();
    await _derivedTextStore.ensureSchema();
    await _systemObjects.ensureSchema();
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

  List<String> _queryTerms(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .map((term) => term.replaceAll('"', '').trim())
      .where((term) => term.isNotEmpty)
      .toList(growable: false);

  String _buildPrefixQueryFromTerms(Iterable<String> terms) =>
      terms.map((term) => '"$term"*').join(' AND ');

  String _buildPrefixQuery(String value) =>
      _buildPrefixQueryFromTerms(_queryTerms(value));

  bool _containsCjk(String value) {
    for (final rune in value.runes) {
      if (rune == 0x3005 ||
          (rune >= 0x3040 && rune <= 0x30ff) ||
          (rune >= 0x31f0 && rune <= 0x31ff) ||
          (rune >= 0x3400 && rune <= 0x4dbf) ||
          (rune >= 0x4e00 && rune <= 0x9fff) ||
          (rune >= 0xf900 && rune <= 0xfaff) ||
          (rune >= 0xff65 && rune <= 0xff9f) ||
          (rune >= 0x20000 && rune <= 0x2fa1f)) {
        return true;
      }
    }
    return false;
  }

  bool _isCjkFallbackBoundaryPunctuation(int rune) =>
      (rune >= 0x21 && rune <= 0x2f) ||
      (rune >= 0x3a && rune <= 0x40) ||
      (rune >= 0x5b && rune <= 0x60) ||
      (rune >= 0x7b && rune <= 0x7e) ||
      (rune >= 0x2000 && rune <= 0x206f) ||
      (rune >= 0x2e00 && rune <= 0x2e7f) ||
      rune == 0x3000 ||
      (rune >= 0x3001 && rune <= 0x3004) ||
      (rune >= 0x3008 && rune <= 0x3011) ||
      (rune >= 0x3014 && rune <= 0x301f) ||
      rune == 0x3030 ||
      rune == 0x30fb ||
      (rune >= 0xfe10 && rune <= 0xfe19) ||
      (rune >= 0xfe30 && rune <= 0xfe4f) ||
      (rune >= 0xff01 && rune <= 0xff0f) ||
      (rune >= 0xff1a && rune <= 0xff20) ||
      (rune >= 0xff3b && rune <= 0xff40) ||
      (rune >= 0xff5b && rune <= 0xff65);

  String _trimCjkFallbackBoundaryPunctuation(String term) {
    final runes = term.runes.toList(growable: false);
    var start = 0;
    var end = runes.length;
    while (start < end && _isCjkFallbackBoundaryPunctuation(runes[start])) {
      start += 1;
    }
    while (end > start && _isCjkFallbackBoundaryPunctuation(runes[end - 1])) {
      end -= 1;
    }
    if (start == 0 && end == runes.length) return term;
    return String.fromCharCodes(runes.sublist(start, end));
  }

  Future<String> _readBodySearchText(int objectId) async {
    try {
      return buildObjectBodySearchText(await _bodyStore.read(objectId));
    } on FormatException {
      // Body parsing intentionally fails closed. Search isolates that corruption
      // to the Body bucket so valid Object identity/Property/Relation text can
      // still be rebuilt, and a focused refresh removes any stale Body tokens.
      return '';
    }
  }

  String _buildRelationLabelsSearchText({
    required AppObject object,
    required Iterable<ResolvedOutgoingRelation> relations,
  }) {
    return buildObjectRelationSearchText(
      relations.where(
        (relation) => !inspectRelationStoredValue(
          object.values[relation.property.id],
        ).isMalformed,
      ),
    );
  }

  Future<String> _readRelationLabelsSearchText({
    required AppObject object,
    required int objectTypeId,
  }) async {
    try {
      return _buildRelationLabelsSearchText(
        object: object,
        relations: await _relationReads.outgoing(
          sourceObjectTypeId: objectTypeId,
          sourceObjectId: object.id,
        ),
      );
    } on FormatException {
      // Relation owns canonical source/target ObjectType validation. If one
      // related schema cannot be decoded, omit only this optional label bucket
      // instead of aborting the otherwise healthy Object projection.
      return '';
    }
  }

  Future<void> _insertObjects({
    int? workspaceId,
    int? objectId,
  }) async {
    if (workspaceId == null && objectId == null) {
      throw ArgumentError('Object search projection insert requires a scope.');
    }
    final conditions = <String>[];
    final variables = <Variable<Object>>[];
    if (workspaceId != null) {
      conditions.add('d.workspace_id = ?');
      variables.add(Variable<int>(workspaceId));
    }
    if (objectId != null) {
      conditions.add('r.id = ?');
      variables.add(Variable<int>(objectId));
    }

    final rows = await _database.customSelect(
      '''SELECT
           r.id AS object_id,
           r.database_id AS object_type_id,
           d.workspace_id AS workspace_id
         FROM generic_records r
         JOIN generic_databases d ON d.id = r.database_id
         WHERE ${conditions.join(' AND ')}
         ORDER BY r.id''',
      variables: variables,
    ).get();

    final typesById = <int, AppObjectType>{};
    final unavailableObjectTypeIds = <int>{};
    final objectsByType = <int, Map<int, AppObject>>{};
    final systemKeysByType = <int, String?>{};
    for (final row in rows) {
      final currentObjectId = row.read<int>('object_id');
      final objectTypeId = row.read<int>('object_type_id');
      if (unavailableObjectTypeIds.contains(objectTypeId)) continue;

      var objectType = typesById[objectTypeId];
      var objectsById = objectsByType[objectTypeId];
      if (objectType == null || objectsById == null) {
        try {
          objectType = await _objectStore.getObjectType(objectTypeId);
        } on FormatException {
          // Object Core owns persisted schema decoding and intentionally fails
          // closed on unsupported/corrupt Property definitions. Search isolates
          // that failure to this ObjectType so healthy types in the same
          // workspace can still rebuild and focused refresh can drop stale rows.
          unavailableObjectTypeIds.add(objectTypeId);
          continue;
        }
        if (objectType == null) {
          unavailableObjectTypeIds.add(objectTypeId);
          continue;
        }
        typesById[objectTypeId] = objectType;
        final objects = await _objectStore.listObjects(objectTypeId);
        objectsById = <int, AppObject>{
          for (final object in objects) object.id: object,
        };
        objectsByType[objectTypeId] = objectsById;
      }
      final object = objectsById[currentObjectId];
      if (object == null) continue;

      if (!systemKeysByType.containsKey(objectTypeId)) {
        systemKeysByType[objectTypeId] =
            await _systemObjects.systemKeyForObjectType(objectTypeId);
      }
      final systemKey = systemKeysByType[objectTypeId];
      final weblinkProjection = systemKey == WeblinkObjectService.systemKey
          ? buildWeblinkSearchProjection(
              object: object,
              objectType: objectType,
            )
          : null;

      final aliases = (await _aliasStore.listAliases(currentObjectId)).join(' ');
      final properties = buildObjectPropertiesSearchText(
        object: object,
        objectType: objectType,
        excludedPropertyIds:
            weblinkProjection?.consumedPropertyIds ?? const <int>{},
      );
      final body = await _readBodySearchText(currentObjectId);
      final relationLabels = await _readRelationLabelsSearchText(
        object: object,
        objectTypeId: objectTypeId,
      );
      final derivedText = await _derivedTextStore.readCombined(currentObjectId);
      await _database.customStatement(
        '''INSERT INTO object_search_fts(
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
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          currentObjectId,
          objectTypeId,
          row.read<int>('workspace_id'),
          object.title,
          aliases,
          properties,
          body,
          relationLabels,
          weblinkProjection?.text ?? '',
          derivedText,
        ],
      );
    }
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
  /// Object is naturally removed because the focused projection query yields
  /// no row, and callers cannot accidentally supply a mismatched workspace.
  Future<void> refreshObject(int objectId) async {
    await initialize();
    await _database.transaction(() async {
      await _deleteRows(await _matchingRowIds(objectId: objectId));
      await _insertObjects(objectId: objectId);
    });
  }

  ObjectSearchHit _hitFromRow(QueryRow row) => ObjectSearchHit(
        objectId: row.read<int>('object_id'),
        objectTypeId: row.read<int>('object_type_id'),
        workspaceId: row.read<int>('workspace_id'),
        rank: row.read<double>('rank'),
        snippet: row.read<String>('snippet'),
      );

  Future<List<ObjectSearchHit>> _searchPrefix({
    required int workspaceId,
    required String query,
    required int limit,
    int? objectTypeId,
  }) async {
    final typeClause = objectTypeId == null
        ? ''
        : 'AND CAST(object_type_id AS INTEGER) = ?';
    final variables = <Variable<Object>>[
      Variable<String>(query),
      Variable<int>(workspaceId),
      if (objectTypeId != null) Variable<int>(objectTypeId),
      Variable<int>(limit),
    ];
    final rows = await _database.customSelect('''
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
      ''', variables: variables).get();
    return rows.map(_hitFromRow).toList(growable: false);
  }

  Future<List<ObjectSearchHit>> _searchCjkSubstringFallback({
    required int workspaceId,
    required List<String> cjkTerms,
    required List<String> prefixTerms,
    required int limit,
    int? objectTypeId,
  }) async {
    final conditions = <String>['CAST(workspace_id AS INTEGER) = ?'];
    final variables = <Variable<Object>>[Variable<int>(workspaceId)];
    final prefixQuery = _buildPrefixQueryFromTerms(prefixTerms);
    if (prefixQuery.isNotEmpty) {
      conditions.add('object_search_fts MATCH ?');
      variables.add(Variable<String>(prefixQuery));
    }
    if (objectTypeId != null) {
      conditions.add('CAST(object_type_id AS INTEGER) = ?');
      variables.add(Variable<int>(objectTypeId));
    }
    for (final term in cjkTerms) {
      final variants = buildCjkWidthCompatibilityVariants(term);
      final predicates = <String>[];
      for (final column in _searchTextColumns) {
        for (final variant in variants) {
          predicates.add('instr(lower($column), lower(?)) > 0');
          variables.add(Variable<String>(variant));
        }
      }
      conditions.add('(${predicates.join(' OR ')})');
    }
    variables.add(Variable<int>(limit));

    final rankExpression = prefixQuery.isEmpty
        ? '0.0'
        : 'bm25(object_search_fts)';
    final snippetExpression = prefixQuery.isEmpty
        ? "''"
        : "snippet(object_search_fts, -1, '‹', '›', ' … ', 20)";
    final rows = await _database.customSelect('''
      SELECT
        CAST(object_id AS INTEGER) AS object_id,
        CAST(object_type_id AS INTEGER) AS object_type_id,
        CAST(workspace_id AS INTEGER) AS workspace_id,
        $rankExpression AS rank,
        $snippetExpression AS snippet
      FROM object_search_fts
      WHERE ${conditions.join(' AND ')}
      ORDER BY rank, object_id
      LIMIT ?
      ''', variables: variables).get();
    return rows.map(_hitFromRow).toList(growable: false);
  }

  Future<List<ObjectSearchHit>> search({
    required int workspaceId,
    required String rawQuery,
    int? objectTypeId,
    int limit = 100,
  }) async {
    await initialize();
    final terms = _queryTerms(rawQuery);
    if (terms.isEmpty) return const <ObjectSearchHit>[];

    final query = _buildPrefixQuery(rawQuery);
    final prefixHits = await _searchPrefix(
      workspaceId: workspaceId,
      query: query,
      objectTypeId: objectTypeId,
      limit: limit,
    );
    final cjkTerms = terms
        .where(_containsCjk)
        .map(_trimCjkFallbackBoundaryPunctuation)
        .where((term) => term.isNotEmpty && _containsCjk(term))
        .toList(growable: false);
    if (cjkTerms.isEmpty || prefixHits.length >= limit) return prefixHits;

    // unicode61 keeps ordinary Japanese text without whitespace in one token
    // and does not fold half-width Katakana to ordinary full-width forms.
    // Prefix MATCH therefore misses either intra-token CJK starts (for example
    // `漱石` in `夏目漱石`) or compatible width variants such as `ｶﾀｶﾅ` versus
    // `カタカナ`. Scan the same canonical projection only for CJK-containing
    // terms, preserving punctuation inside the term and keeping non-CJK terms
    // on the existing prefix FTS path. This adds no second index and does not
    // broaden ordinary Latin infix search.
    final fallbackHits = await _searchCjkSubstringFallback(
      workspaceId: workspaceId,
      cjkTerms: cjkTerms,
      prefixTerms: terms.where((term) => !_containsCjk(term)).toList(),
      objectTypeId: objectTypeId,
      limit: limit,
    );
    final seenObjectIds = prefixHits.map((hit) => hit.objectId).toSet();
    final merged = <ObjectSearchHit>[...prefixHits];
    for (final hit in fallbackHits) {
      if (!seenObjectIds.add(hit.objectId)) continue;
      merged.add(hit);
      if (merged.length >= limit) break;
    }
    return List<ObjectSearchHit>.unmodifiable(merged);
  }
}
