import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/object_history_relation.dart';
import 'generic_database_store.dart';

/// Restart-safe B-owned persistence for immutable Relation history snapshots.
///
/// Current Relation values and edge indexes remain authoritative. This store is
/// historical evidence only and never mutates canonical Relation state.
class ObjectHistoryRelationStore {
  ObjectHistoryRelationStore(this._genericStore);

  final GenericDatabaseStore _genericStore;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() async {
    while (true) {
      final ready = _schemaReady ??= _createSchema();
      try {
        await ready;
      } catch (_) {
        if (identical(_schemaReady, ready)) {
          _schemaReady = null;
        }
        rethrow;
      }

      if (await _schemaExists()) return;
      if (identical(_schemaReady, ready)) {
        _schemaReady = null;
      }
    }
  }

  /// Appends one immutable Relation snapshot for an Object revision.
  ///
  /// Repeating the exact same historical key and payload is idempotent and
  /// returns `false`. Reusing the key for different historical evidence fails
  /// closed before mutation.
  Future<bool> append({
    required int revisionId,
    required ObjectHistoryRelationSnapshot snapshot,
  }) async {
    _validatePositiveId(revisionId, 'revisionId');
    await ensureSchema();
    final encoded = _encode(revisionId: revisionId, snapshot: snapshot);

    return _genericStore.database.transaction(() async {
      final existing = await _loadRow(
        sourceObjectId: snapshot.sourceObjectId,
        revisionId: revisionId,
        propertyId: snapshot.propertyId,
      );
      if (existing != null) {
        if (_encode(
              revisionId: existing.revisionId,
              snapshot: existing.snapshot,
            ) ==
            encoded) {
          return false;
        }
        throw StateError(
          'Relation history for Object ${snapshot.sourceObjectId}, revision '
          '$revisionId, Property ${snapshot.propertyId} already exists with '
          'different snapshot content.',
        );
      }

      await _genericStore.database.customStatement(
        '''INSERT INTO object_history_relation_snapshots(
             source_object_id, revision_id, property_id, payload_json
           ) VALUES (?, ?, ?, ?)''',
        [
          snapshot.sourceObjectId,
          revisionId,
          snapshot.propertyId,
          encoded,
        ],
      );
      return true;
    });
  }

  Future<ObjectHistoryRelationSnapshot?> load({
    required int sourceObjectId,
    required int revisionId,
    required int propertyId,
  }) async {
    _validatePositiveId(sourceObjectId, 'sourceObjectId');
    _validatePositiveId(revisionId, 'revisionId');
    _validatePositiveId(propertyId, 'propertyId');
    await ensureSchema();
    final row = await _loadRow(
      sourceObjectId: sourceObjectId,
      revisionId: revisionId,
      propertyId: propertyId,
    );
    return row?.snapshot;
  }

  Future<List<ObjectHistoryRelationSnapshot>> listForRevision({
    required int sourceObjectId,
    required int revisionId,
  }) async {
    _validatePositiveId(sourceObjectId, 'sourceObjectId');
    _validatePositiveId(revisionId, 'revisionId');
    await ensureSchema();

    final rows = await _genericStore.database
        .customSelect(
          '''SELECT source_object_id, revision_id, property_id, payload_json
             FROM object_history_relation_snapshots
             WHERE source_object_id = ? AND revision_id = ?
             ORDER BY property_id''',
          variables: <Variable<Object>>[
            Variable<int>(sourceObjectId),
            Variable<int>(revisionId),
          ],
        )
        .get();

    final snapshots = <ObjectHistoryRelationSnapshot>[];
    final propertyIds = <int>{};
    for (final row in rows) {
      final decoded = _decodeRow(row);
      if (!propertyIds.add(decoded.snapshot.propertyId)) {
        throw StateError(
          'Relation history revision contains duplicate Property snapshots.',
        );
      }
      snapshots.add(decoded.snapshot);
    }
    return List<ObjectHistoryRelationSnapshot>.unmodifiable(snapshots);
  }

  Future<void> _createSchema() => _genericStore.database.transaction(() async {
    await _genericStore.ensureSchema();
    await _genericStore.database.customStatement('''
      CREATE TABLE IF NOT EXISTS object_history_relation_snapshots (
        source_object_id INTEGER NOT NULL CHECK(source_object_id > 0),
        revision_id INTEGER NOT NULL CHECK(revision_id > 0),
        property_id INTEGER NOT NULL CHECK(property_id > 0),
        payload_json TEXT NOT NULL CHECK(length(payload_json) > 0),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY(source_object_id, revision_id, property_id)
      )
    ''');
  });

  Future<bool> _schemaExists() async {
    final row = await _genericStore.database
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'object_history_relation_snapshots' LIMIT 1",
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<_StoredRelationSnapshot?> _loadRow({
    required int sourceObjectId,
    required int revisionId,
    required int propertyId,
  }) async {
    final row = await _genericStore.database
        .customSelect(
          '''SELECT source_object_id, revision_id, property_id, payload_json
             FROM object_history_relation_snapshots
             WHERE source_object_id = ? AND revision_id = ? AND property_id = ?
             LIMIT 1''',
          variables: <Variable<Object>>[
            Variable<int>(sourceObjectId),
            Variable<int>(revisionId),
            Variable<int>(propertyId),
          ],
        )
        .getSingleOrNull();
    return row == null ? null : _decodeRow(row);
  }

  _StoredRelationSnapshot _decodeRow(QueryRow row) {
    final storedSourceObjectId = row.read<int>('source_object_id');
    final storedRevisionId = row.read<int>('revision_id');
    final storedPropertyId = row.read<int>('property_id');
    final payload = _decode(row.read<String>('payload_json'));

    if (payload.revisionId != storedRevisionId ||
        payload.snapshot.sourceObjectId != storedSourceObjectId ||
        payload.snapshot.propertyId != storedPropertyId) {
      throw StateError(
        'Stored Relation history key does not match its snapshot payload.',
      );
    }
    return payload;
  }

  _StoredRelationSnapshot _decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Relation history payload must be a JSON object.',
      );
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported Relation history store payload.');
    }
    final revisionId = json['revisionId'];
    final rawSnapshot = json['snapshot'];
    if (revisionId is! int || revisionId <= 0 || rawSnapshot is! Map) {
      throw const FormatException('Malformed Relation history store payload.');
    }
    return _StoredRelationSnapshot(
      revisionId: revisionId,
      snapshot: ObjectHistoryRelationSnapshot.fromJson(
        Map<String, dynamic>.from(rawSnapshot),
      ),
    );
  }

  String _encode({
    required int revisionId,
    required ObjectHistoryRelationSnapshot snapshot,
  }) => jsonEncode(<String, dynamic>{
    'schemaVersion': 1,
    'revisionId': revisionId,
    'snapshot': snapshot.toJson(),
  });
}

class _StoredRelationSnapshot {
  const _StoredRelationSnapshot({
    required this.revisionId,
    required this.snapshot,
  });

  final int revisionId;
  final ObjectHistoryRelationSnapshot snapshot;
}

void _validatePositiveId(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, '$name must be positive.');
  }
}
