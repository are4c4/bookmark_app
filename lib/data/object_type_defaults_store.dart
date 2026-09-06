import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/object_body.dart';
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
    await _validatePropertyReferences(
      objectTypeId: objectTypeId,
      defaults: defaults,
    );
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

  /// Updates only the Object creation Body template.
  ///
  /// Presentation defaults remain intact so a future ObjectType template editor
  /// cannot accidentally erase Property visibility/order or opening behavior.
  /// Passing `null` removes the Body template; if no other ObjectType defaults
  /// remain, the persisted defaults row is removed through [write].
  Future<void> writeBodyTemplate({
    required int objectTypeId,
    required ObjectBodyDocument? bodyTemplate,
  }) async {
    final current = await read(objectTypeId) ?? const ObjectTypeDefaults();
    await write(
      objectTypeId: objectTypeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: current.visiblePropertyIds,
        propertyOrder: current.propertyOrder,
        openMode: current.openMode,
        bodyTemplate: bodyTemplate,
      ),
    );
  }

  Future<void> clear(int objectTypeId) async {
    await ensureSchema();
    await _genericStore.database.customStatement(
      'DELETE FROM object_type_defaults WHERE object_type_id = ?',
      [objectTypeId],
    );
  }

  Future<void> _validatePropertyReferences({
    required int objectTypeId,
    required ObjectTypeDefaults defaults,
  }) async {
    final objectType = await _genericStore.getDatabase(objectTypeId);
    if (objectType == null) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'ObjectType does not exist.',
      );
    }

    final referencedIds = <int>{
      ...?defaults.visiblePropertyIds,
      ...?defaults.propertyOrder,
    };
    if (referencedIds.isEmpty) return;

    final propertyIds = (await _genericStore.listProperties(objectTypeId))
        .map((property) => property.id)
        .toSet();
    final invalidIds = referencedIds
        .where((propertyId) => !propertyIds.contains(propertyId))
        .toList(growable: false)
      ..sort();
    if (invalidIds.isNotEmpty) {
      throw ArgumentError.value(
        invalidIds,
        'defaults',
        'ObjectType defaults may reference only Properties owned by ObjectType '
            '$objectTypeId.',
      );
    }
  }
}
