import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/object_body.dart';
import '../domain/object_body_block_contracts.dart';
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
    final document = ObjectBodyDocument.fromJson(decoded);
    ObjectBodyBlockContractValidator.validateDocument(document);
    return document;
  }

  Future<void> write({
    required int objectId,
    required ObjectBodyDocument document,
  }) async {
    ObjectBodyBlockContractValidator.validateDocument(document);
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

  /// Replaces the persisted Body only when it still semantically matches
  /// [expected].
  ///
  /// Accepted historical/non-canonical JSON encodings are decoded through the
  /// same compatibility path as [read] before semantic comparison. The final
  /// write is nevertheless conditioned on the exact raw snapshot read inside
  /// the transaction, so a real concurrent persisted change is never
  /// overwritten merely because both snapshots decode successfully.
  Future<bool> writeIfUnchanged({
    required int objectId,
    required ObjectBodyDocument expected,
    required ObjectBodyDocument document,
  }) async {
    ObjectBodyBlockContractValidator.validateDocument(expected);
    ObjectBodyBlockContractValidator.validateDocument(document);
    await ensureSchema();
    return _genericStore.database.transaction(() async {
      final row = await _genericStore.database
          .customSelect(
            'SELECT document_json FROM object_bodies WHERE object_id = ? LIMIT 1',
            variables: [Variable<int>(objectId)],
          )
          .getSingleOrNull();

      final expectedCanonical = jsonEncode(expected.toJson());
      final nextCanonical = jsonEncode(document.toJson());

      if (row == null) {
        final emptyCanonical = jsonEncode(const ObjectBodyDocument().toJson());
        if (expectedCanonical != emptyCanonical) return false;

        await _genericStore.database.customStatement(
          '''INSERT OR IGNORE INTO object_bodies(
               object_id, document_json, updated_at
             ) VALUES (?, ?, CURRENT_TIMESTAMP)''',
          [objectId, nextCanonical],
        );
      } else {
        final raw = row.read<String>('document_json');
        dynamic decoded;
        try {
          decoded = jsonDecode(raw);
        } on FormatException {
          throw const FormatException('Stored Object body is not valid JSON.');
        }
        final stored = ObjectBodyDocument.fromJson(decoded);
        ObjectBodyBlockContractValidator.validateDocument(stored);
        if (jsonEncode(stored.toJson()) != expectedCanonical) return false;

        await _genericStore.database.customStatement(
          '''UPDATE object_bodies
             SET document_json = ?, updated_at = CURRENT_TIMESTAMP
             WHERE object_id = ? AND document_json = ?''',
          [nextCanonical, objectId, raw],
        );
      }

      final changeRow = await _genericStore.database
          .customSelect('SELECT changes() AS affected')
          .getSingle();
      if (changeRow.read<int>('affected') == 0) return false;

      await _genericStore.database.customStatement(
        'UPDATE generic_records SET updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [objectId],
      );
      return true;
    });
  }

  /// Removes Body content only. The Object itself and all Properties remain.
  ///
  /// Clearing existing Body content is still an Object content mutation, so it
  /// advances the parent Object's freshness just like [write]. An already-empty
  /// Body is a no-op and does not make the Object appear newly updated.
  Future<void> clear(int objectId) async {
    await ensureSchema();
    await _genericStore.database.transaction(() async {
      await _genericStore.database.customStatement(
        'DELETE FROM object_bodies WHERE object_id = ?',
        [objectId],
      );
      final changeRow = await _genericStore.database.customSelect(
        'SELECT changes() AS affected',
      ).getSingle();
      if (changeRow.read<int>('affected') == 0) return;

      await _genericStore.database.customStatement(
        'UPDATE generic_records SET updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [objectId],
      );
    });
  }
}
