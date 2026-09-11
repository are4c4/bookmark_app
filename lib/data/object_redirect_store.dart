import 'package:drift/drift.dart';

import '../domain/object_merge_contract.dart';
import 'generic_database_store.dart';

/// Durable A-owned mapping from retired Object ids to surviving Object ids.
///
/// Redirect rows intentionally do not reference `generic_records` with foreign
/// keys. A retired id must remain resolvable after its Object row is eventually
/// removed, and an intermediate survivor may itself be retired later to form a
/// historical redirect chain.
class ObjectRedirectStore {
  ObjectRedirectStore(this._genericStore);

  final GenericDatabaseStore _genericStore;
  final ObjectRedirectResolver _resolver = const ObjectRedirectResolver();
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

  Future<bool> recordRedirect({
    required int retiredObjectId,
    required int survivorObjectId,
  }) async {
    _validateRedirectIds(
      retiredObjectId: retiredObjectId,
      survivorObjectId: survivorObjectId,
    );
    await ensureSchema();

    return _genericStore.database.transaction(() async {
      final redirects = await _readRedirects();
      _resolver.resolve(objectId: retiredObjectId, redirects: redirects);

      final existing = redirects[retiredObjectId];
      if (existing != null) {
        if (existing == survivorObjectId) return false;
        throw StateError(
          'Retired Object $retiredObjectId is already redirected to $existing.',
        );
      }

      final candidate = <int, int>{
        ...redirects,
        retiredObjectId: survivorObjectId,
      };
      _resolver.resolve(objectId: retiredObjectId, redirects: candidate);

      await _genericStore.database.customStatement(
        '''INSERT INTO object_redirects(
             retired_object_id, survivor_object_id
           ) VALUES (?, ?)''',
        [retiredObjectId, survivorObjectId],
      );
      return true;
    });
  }

  Future<int> resolve(int objectId) async {
    await ensureSchema();
    final redirects = await _readRedirects();
    return _resolver.resolve(objectId: objectId, redirects: redirects);
  }

  Future<void> _createSchema() => _genericStore.database.transaction(() async {
    await _genericStore.ensureSchema();
    await _genericStore.database.customStatement('''
      CREATE TABLE IF NOT EXISTS object_redirects (
        retired_object_id INTEGER PRIMARY KEY
          CHECK(retired_object_id > 0),
        survivor_object_id INTEGER NOT NULL
          CHECK(survivor_object_id > 0),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CHECK(retired_object_id <> survivor_object_id)
      )
    ''');
  });

  Future<bool> _schemaExists() async {
    final row = await _genericStore.database.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'object_redirects' LIMIT 1",
    ).getSingleOrNull();
    return row != null;
  }

  Future<Map<int, int>> _readRedirects() async {
    final rows = await _genericStore.database.customSelect(
      '''SELECT retired_object_id, survivor_object_id
         FROM object_redirects
         ORDER BY retired_object_id''',
    ).get();
    return <int, int>{
      for (final row in rows)
        row.read<int>('retired_object_id'):
            row.read<int>('survivor_object_id'),
    };
  }
}

void _validateRedirectIds({
  required int retiredObjectId,
  required int survivorObjectId,
}) {
  if (retiredObjectId <= 0 || survivorObjectId <= 0) {
    throw ArgumentError('Object redirect ids must be positive.');
  }
  if (retiredObjectId == survivorObjectId) {
    throw ArgumentError('An Object cannot redirect to itself.');
  }
}
