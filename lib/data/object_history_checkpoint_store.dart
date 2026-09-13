import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/object_history_checkpoint.dart';
import '../domain/object_history_checkpoint_codec.dart';
import 'generic_database_store.dart';

/// Restart-safe A-owned persistence for immutable Object history checkpoints.
///
/// Only [ObjectHistoryCheckpointPayload] is stored here. Relation target/order
/// history stays behind Lane B's Relation history boundary, and managed-byte
/// retention/deletion remains Lane F-owned.
class ObjectHistoryCheckpointStore {
  ObjectHistoryCheckpointStore(
    this._genericStore, {
    this.codec = const ObjectHistoryCheckpointCodec(),
  });

  final GenericDatabaseStore _genericStore;
  final ObjectHistoryCheckpointCodec codec;
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

  /// Appends one immutable checkpoint to an Object's linear revision chain.
  ///
  /// Repeating the exact same checkpoint is idempotent and returns `false`.
  /// Reusing a revision id for different content, skipping the current chain
  /// head, or appending an older revision fails before mutation.
  Future<bool> append(ObjectHistoryCheckpointPayload checkpoint) async {
    await ensureSchema();
    final encoded = _encode(checkpoint);
    final entry = checkpoint.entry;

    return _genericStore.database.transaction(() async {
      final existing = await _loadValidated(entry.objectId);
      for (final candidate in existing) {
        if (candidate.entry.revisionId != entry.revisionId) continue;
        if (_encode(candidate) == encoded) return false;
        throw StateError(
          'Object ${entry.objectId} history revision ${entry.revisionId} '
          'already exists with different checkpoint content.',
        );
      }

      final latest = existing.isEmpty ? null : existing.last;
      if (latest == null) {
        if (entry.previousRevisionId != null) {
          throw StateError(
            'The first Object history checkpoint cannot name a previous revision.',
          );
        }
      } else {
        if (entry.revisionId <= latest.entry.revisionId) {
          throw StateError(
            'Object history revisions must advance beyond the current latest revision.',
          );
        }
        if (entry.previousRevisionId != latest.entry.revisionId) {
          throw StateError(
            'Object history checkpoint must extend the current latest revision.',
          );
        }
      }

      await _genericStore.database.customStatement(
        '''INSERT INTO object_history_checkpoints(
             object_id, revision_id, payload_json
           ) VALUES (?, ?, ?)''',
        [entry.objectId, entry.revisionId, encoded],
      );
      return true;
    });
  }

  Future<ObjectHistoryCheckpointPayload?> load({
    required int objectId,
    required int revisionId,
  }) async {
    _validatePositiveId(objectId, 'objectId');
    _validatePositiveId(revisionId, 'revisionId');
    final checkpoints = await list(objectId);
    for (final checkpoint in checkpoints) {
      if (checkpoint.entry.revisionId == revisionId) return checkpoint;
    }
    return null;
  }

  Future<List<ObjectHistoryCheckpointPayload>> list(int objectId) async {
    _validatePositiveId(objectId, 'objectId');
    await ensureSchema();
    return List<ObjectHistoryCheckpointPayload>.unmodifiable(
      await _loadValidated(objectId),
    );
  }

  Future<ObjectHistoryCheckpointPayload?> latest(int objectId) async {
    final checkpoints = await list(objectId);
    return checkpoints.isEmpty ? null : checkpoints.last;
  }

  Future<void> _createSchema() => _genericStore.database.transaction(() async {
    await _genericStore.ensureSchema();
    await _genericStore.database.customStatement('''
      CREATE TABLE IF NOT EXISTS object_history_checkpoints (
        object_id INTEGER NOT NULL CHECK(object_id > 0),
        revision_id INTEGER NOT NULL CHECK(revision_id > 0),
        payload_json TEXT NOT NULL CHECK(length(payload_json) > 0),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY(object_id, revision_id)
      )
    ''');
  });

  Future<bool> _schemaExists() async {
    final row = await _genericStore.database
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'object_history_checkpoints' LIMIT 1",
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<List<ObjectHistoryCheckpointPayload>> _loadValidated(
    int objectId,
  ) async {
    final rows = await _genericStore.database
        .customSelect(
          '''SELECT object_id, revision_id, payload_json
         FROM object_history_checkpoints
         WHERE object_id = ?
         ORDER BY revision_id''',
          variables: [Variable<int>(objectId)],
        )
        .get();

    final checkpoints = <ObjectHistoryCheckpointPayload>[];
    for (final row in rows) {
      final storedObjectId = row.read<int>('object_id');
      final storedRevisionId = row.read<int>('revision_id');
      final payloadJson = row.read<String>('payload_json');
      final payload = _decode(payloadJson);
      if (payload.entry.objectId != storedObjectId ||
          payload.entry.revisionId != storedRevisionId) {
        throw StateError(
          'Stored Object history key does not match its checkpoint payload.',
        );
      }
      checkpoints.add(payload);
    }
    _validateChain(objectId, checkpoints);
    return checkpoints;
  }

  ObjectHistoryCheckpointPayload _decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Object history checkpoint payload must be a JSON object.',
      );
    }
    return codec.decode(Map<String, dynamic>.from(decoded));
  }

  String _encode(ObjectHistoryCheckpointPayload checkpoint) =>
      jsonEncode(codec.encode(checkpoint));
}

void _validateChain(
  int objectId,
  List<ObjectHistoryCheckpointPayload> checkpoints,
) {
  ObjectHistoryCheckpointPayload? previous;
  for (final checkpoint in checkpoints) {
    final entry = checkpoint.entry;
    if (entry.objectId != objectId) {
      throw StateError('Object history checkpoint belongs to another Object.');
    }
    if (previous == null) {
      if (entry.previousRevisionId != null) {
        throw StateError(
          'Object history chain does not start at a root revision.',
        );
      }
    } else {
      if (entry.revisionId <= previous.entry.revisionId ||
          entry.previousRevisionId != previous.entry.revisionId) {
        throw StateError('Object history revision chain is broken.');
      }
    }
    previous = checkpoint;
  }
}

void _validatePositiveId(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, '$name must be positive.');
  }
}
