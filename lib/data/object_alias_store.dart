import 'package:drift/drift.dart';

import '../domain/object_alias.dart';
import 'generic_database_store.dart';

/// Additive persistence for Object-level alternate names.
///
/// Aliases are scoped to one Object. The same alias may intentionally resolve
/// to multiple Objects, while duplicate normalized aliases within one Object
/// are rejected by the primary key.
class ObjectAliasStore {
  ObjectAliasStore(this._genericStore);

  final GenericDatabaseStore _genericStore;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??=
      _genericStore.database.transaction(() async {
        await _genericStore.ensureSchema();
        await _genericStore.database.customStatement('''
          CREATE TABLE IF NOT EXISTS object_aliases (
            object_id INTEGER NOT NULL
              REFERENCES generic_records(id) ON DELETE CASCADE,
            alias TEXT NOT NULL,
            normalized_alias TEXT NOT NULL,
            position INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(object_id, normalized_alias)
          )
        ''');
        await _genericStore.database.customStatement(
          'CREATE INDEX IF NOT EXISTS object_aliases_lookup_idx '
          'ON object_aliases(normalized_alias, object_id)',
        );
      });

  Future<List<ObjectAliasEntry>> listEntries(int objectId) async {
    await ensureSchema();
    final rows = await _genericStore.database.customSelect(
      '''SELECT object_id, alias, normalized_alias, position
         FROM object_aliases
         WHERE object_id = ?
         ORDER BY position, normalized_alias''',
      variables: [Variable<int>(objectId)],
    ).get();
    return rows
        .map(
          (row) => ObjectAliasEntry(
            objectId: row.read<int>('object_id'),
            alias: row.read<String>('alias'),
            normalizedAlias: row.read<String>('normalized_alias'),
            position: row.read<int>('position'),
          ),
        )
        .toList(growable: false);
  }

  Future<List<String>> listAliases(int objectId) async =>
      (await listEntries(objectId))
          .map((entry) => entry.alias)
          .toList(growable: false);

  Future<void> replaceAliases({
    required int objectId,
    required Iterable<String> aliases,
  }) async {
    await ensureSchema();
    final canonical = canonicalizeObjectAliases(aliases);
    await _genericStore.database.transaction(() async {
      await _requireObject(objectId);
      await _genericStore.database.customStatement(
        'DELETE FROM object_aliases WHERE object_id = ?',
        [objectId],
      );
      for (var index = 0; index < canonical.length; index++) {
        final alias = canonical[index];
        await _genericStore.database.customStatement(
          '''INSERT INTO object_aliases(
               object_id, alias, normalized_alias, position
             ) VALUES (?, ?, ?, ?)''',
          [objectId, alias, normalizeObjectAlias(alias), index],
        );
      }
    });
  }

  /// Adds one alias, returning false when the same normalized alias already
  /// exists on this Object.
  Future<bool> addAlias({
    required int objectId,
    required String alias,
  }) async {
    await ensureSchema();
    final cleaned = cleanObjectAlias(alias);
    if (cleaned.isEmpty) {
      throw ArgumentError.value(alias, 'alias', 'Alias must not be blank.');
    }
    final normalized = normalizeObjectAlias(cleaned);
    return _genericStore.database.transaction(() async {
      await _requireObject(objectId);
      final existing = await _genericStore.database.customSelect(
        '''SELECT 1 FROM object_aliases
           WHERE object_id = ? AND normalized_alias = ?
           LIMIT 1''',
        variables: [
          Variable<int>(objectId),
          Variable<String>(normalized),
        ],
      ).getSingleOrNull();
      if (existing != null) return false;

      final maxRow = await _genericStore.database.customSelect(
        '''SELECT MAX(position) AS max_position
           FROM object_aliases
           WHERE object_id = ?''',
        variables: [Variable<int>(objectId)],
      ).getSingle();
      final maxPosition = maxRow.readNullable<int>('max_position');
      await _genericStore.database.customStatement(
        '''INSERT INTO object_aliases(
             object_id, alias, normalized_alias, position
           ) VALUES (?, ?, ?, ?)''',
        [objectId, cleaned, normalized, (maxPosition ?? -1) + 1],
      );
      return true;
    });
  }

  Future<void> removeAlias({
    required int objectId,
    required String alias,
  }) async {
    await ensureSchema();
    final normalized = normalizeObjectAlias(alias);
    if (normalized.isEmpty) return;
    await _genericStore.database.customStatement(
      '''DELETE FROM object_aliases
         WHERE object_id = ? AND normalized_alias = ?''',
      [objectId, normalized],
    );
    await _compactPositions(objectId);
  }

  Future<void> clear(int objectId) async {
    await ensureSchema();
    await _genericStore.database.customStatement(
      'DELETE FROM object_aliases WHERE object_id = ?',
      [objectId],
    );
  }

  Future<void> _requireObject(int objectId) async {
    final row = await _genericStore.database.customSelect(
      'SELECT id FROM generic_records WHERE id = ? LIMIT 1',
      variables: [Variable<int>(objectId)],
    ).getSingleOrNull();
    if (row == null) {
      throw ArgumentError.value(objectId, 'objectId', 'Object does not exist.');
    }
  }

  Future<void> _compactPositions(int objectId) async {
    final entries = await listEntries(objectId);
    await _genericStore.database.transaction(() async {
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        if (entry.position == index) continue;
        await _genericStore.database.customStatement(
          '''UPDATE object_aliases SET position = ?
             WHERE object_id = ? AND normalized_alias = ?''',
          [index, objectId, entry.normalizedAlias],
        );
      }
    });
  }
}
