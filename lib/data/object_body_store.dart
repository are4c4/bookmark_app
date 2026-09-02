import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/object_body.dart';
import 'generic_database_store.dart';

/// Backward-compatible persistence for Object Body documents.
///
/// The table is created lazily and additively. Existing generic record/property
/// storage is left untouched, so adopting Body does not rewrite user data.
class ObjectBodyStore {
  ObjectBodyStore(this._genericStore);

  final GenericDatabaseStore _genericStore;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??=
      _genericStore.database.transaction(() async {
        await _genericStore.ensureSchema();
        await _genericStore.database.customStatement('''
          CREATE TABLE IF NOT EXISTS object_bodies (
            object_id INTEGER PRIMARY KEY
              REFERENCES generic_records(id) ON DELETE CASCADE,
            document_json TEXT NOT NULL,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      });

  Future<ObjectBodyDocument> read(int objectId) async {
    await ensureSchema();
    final row = await _genericStore.database.customSelect(
      'SELECT document_json FROM object_bodies WHERE object_id = ? LIMIT 1',
      variables: [Variable<int>(objectId)],
    ).getSingleOrNull();
    if (row == null) return const ObjectBodyDocument();

    final raw = row.read<String>('document_json');
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Stored Object body is not valid JSON.');
    }
    return ObjectBodyDocument.fromJson(decoded);
  }

  Future<void> write({
    required int objectId,
    required ObjectBodyDocument document,
  }) async {
    await ensureSchema();
    await _genericStore.database.transaction(() async {
      await _genericStore.database.customStatement(
        '''INSERT INTO object_bodies(object_id, document_json, updated_at)
           VALUES (?, ?, CURRENT_TIMESTAMP)
           ON CONFLICT(object_id)
           DO UPDATE SET
             document_json = excluded.document_json,
             updated_at = CURRENT_TIMESTAMP''',
        [objectId, jsonEncode(document.toJson())],
      );
      await _genericStore.database.customStatement(
        'UPDATE generic_records SET updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [objectId],
      );
    });
  }

  /// Removes Body content only. The Object itself and all Properties remain.
  Future<void> clear(int objectId) async {
    await ensureSchema();
    await _genericStore.database.customStatement(
      'DELETE FROM object_bodies WHERE object_id = ?',
      [objectId],
    );
  }
}
