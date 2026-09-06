import 'package:drift/drift.dart';

import '../data/generic_database_store.dart';

/// Search-only persistence for replaceable text derived from an Object's
/// external/native content, such as PDF extraction.
///
/// The producer owns extraction and source semantics. Search owns only this
/// rebuildable contribution boundary. Each source replaces its own text so a
/// retry/update cannot accumulate stale tokens, and raw text is never logged.
class ObjectDerivedSearchTextStore {
  ObjectDerivedSearchTextStore(this._genericStore);

  final GenericDatabaseStore _genericStore;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??=
      _genericStore.database.transaction(() async {
        await _genericStore.ensureSchema();
        await _genericStore.database.customStatement('''
          CREATE TABLE IF NOT EXISTS object_search_derived_text (
            object_id INTEGER NOT NULL
              REFERENCES generic_records(id) ON DELETE CASCADE,
            source_key TEXT NOT NULL,
            search_text TEXT NOT NULL,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY(object_id, source_key)
          )
        ''');
        await _genericStore.database.customStatement(
          'CREATE INDEX IF NOT EXISTS object_search_derived_text_object_idx '
          'ON object_search_derived_text(object_id, source_key)',
        );
      });

  /// Replaces one producer's contribution. Blank text removes that source.
  Future<void> replace({
    required int objectId,
    required String sourceKey,
    required String text,
  }) async {
    await ensureSchema();
    final source = sourceKey.trim();
    if (source.isEmpty) {
      throw ArgumentError.value(
        sourceKey,
        'sourceKey',
        'Derived search-text source must not be blank.',
      );
    }
    final normalizedText = text.trim();
    await _genericStore.database.transaction(() async {
      await _requireObject(objectId);
      if (normalizedText.isEmpty) {
        await _genericStore.database.customStatement(
          '''DELETE FROM object_search_derived_text
             WHERE object_id = ? AND source_key = ?''',
          [objectId, source],
        );
        return;
      }
      await _genericStore.database.customStatement(
        '''INSERT INTO object_search_derived_text(
             object_id, source_key, search_text, updated_at
           ) VALUES (?, ?, ?, CURRENT_TIMESTAMP)
           ON CONFLICT(object_id, source_key)
           DO UPDATE SET
             search_text = excluded.search_text,
             updated_at = CURRENT_TIMESTAMP''',
        [objectId, source, normalizedText],
      );
    });
  }

  Future<void> clearSource({
    required int objectId,
    required String sourceKey,
  }) async {
    await ensureSchema();
    final source = sourceKey.trim();
    if (source.isEmpty) return;
    await _genericStore.database.customStatement(
      '''DELETE FROM object_search_derived_text
         WHERE object_id = ? AND source_key = ?''',
      [objectId, source],
    );
  }

  Future<void> clearObject(int objectId) async {
    await ensureSchema();
    await _genericStore.database.customStatement(
      'DELETE FROM object_search_derived_text WHERE object_id = ?',
      [objectId],
    );
  }

  /// Returns the current search contribution in deterministic source order.
  Future<String> readCombined(int objectId) async {
    await ensureSchema();
    final rows = await _genericStore.database.customSelect(
      '''SELECT search_text
         FROM object_search_derived_text
         WHERE object_id = ?
         ORDER BY source_key''',
      variables: [Variable<int>(objectId)],
    ).get();
    return rows
        .map((row) => row.read<String>('search_text').trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  Future<void> _requireObject(int objectId) async {
    final row = await _genericStore.database.customSelect(
      'SELECT 1 FROM generic_records WHERE id = ? LIMIT 1',
      variables: [Variable<int>(objectId)],
    ).getSingleOrNull();
    if (row == null) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'Object does not exist.',
      );
    }
  }
}
