import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/object_type_defaults.dart';
import 'generic_database_store.dart';

/// Persistence owned by ObjectType defaults only.
///
/// Database/View overrides deliberately live elsewhere so inheritance remains
/// `View > Database > ObjectType > app fallback` instead of being flattened.
class ObjectTypeDefaultsStore {
  ObjectTypeDefaultsStore(this._genericStore);

  final GenericDatabaseStore _genericStore;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??=
      _genericStore.database.transaction(() async {
        await _genericStore.ensureSchema();
        await _genericStore.database.customStatement('''
          CREATE TABLE IF NOT EXISTS object_type_defaults (
            object_type_id INTEGER PRIMARY KEY
              REFERENCES generic_databases(id) ON DELETE CASCADE,
            defaults_json TEXT NOT NULL DEFAULT '{}',
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      });

  Future<ObjectTypeDefaults?> read(int objectTypeId) async {
    await ensureSchema();
    final row = await _genericStore.database.customSelect(
      'SELECT defaults_json FROM object_type_defaults '
      'WHERE object_type_id = ? LIMIT 1',
      variables: [Variable<int>(objectTypeId)],
    ).getSingleOrNull();
    if (row == null) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(row.read<String>('defaults_json'));
    } on FormatException {
      throw const FormatException('Stored ObjectType defaults are not valid JSON.');
    }
    return ObjectTypeDefaults.fromJson(decoded);
  }

  Future<void> write({
    required int objectTypeId,
    required ObjectTypeDefaults defaults,
  }) async {
    await ensureSchema();
    if (!defaults.hasOverrides) {
      await clear(objectTypeId);
      return;
    }
    await _genericStore.database.customStatement(
      '''INSERT INTO object_type_defaults(object_type_id, defaults_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(object_type_id)
         DO UPDATE SET
           defaults_json = excluded.defaults_json,
           updated_at = CURRENT_TIMESTAMP''',
      [objectTypeId, jsonEncode(defaults.toJson())],
    );
  }

  Future<void> clear(int objectTypeId) async {
    await ensureSchema();
    await _genericStore.database.customStatement(
      'DELETE FROM object_type_defaults WHERE object_type_id = ?',
      [objectTypeId],
    );
  }
}
