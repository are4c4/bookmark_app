import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';

class GenericDatabaseDefinitionRecord {
  const GenericDatabaseDefinitionRecord({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.icon,
    required this.sortOrder,
  });

  final int id;
  final int workspaceId;
  final String name;
  final String icon;
  final int sortOrder;

  String get databaseKey => 'custom:$id';
}

class GenericPropertyRecord {
  const GenericPropertyRecord({
    required this.id,
    required this.databaseId,
    required this.name,
    required this.type,
    required this.config,
    required this.sortOrder,
  });

  final int id;
  final int databaseId;
  final String name;
  final String type;
  final Map<String, dynamic> config;
  final int sortOrder;
}

class GenericRecord {
  const GenericRecord({
    required this.id,
    required this.databaseId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.values,
  });

  final int id;
  final int databaseId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<int, dynamic> values;
}

class GenericDatabaseStore {
  GenericDatabaseStore(this.database);

  final AppDatabase database;
  Future<void>? _schemaReady;

  static void _debugJsonFallback(String valueKind, StackTrace stackTrace) {
    assert(() {
      stderr.writeln(
        'GenericDatabaseStore: invalid persisted $valueKind JSON; using fallback.',
      );
      stderr.writeln(stackTrace);
      return true;
    }());
  }

  Future<void> ensureSchema() => _schemaReady ??= database.transaction(() async {
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS generic_databases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            icon TEXT NOT NULL DEFAULT '🗃️',
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS generic_properties (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            database_id INTEGER NOT NULL REFERENCES generic_databases(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            config_json TEXT NOT NULL DEFAULT '{}',
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS generic_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            database_id INTEGER NOT NULL REFERENCES generic_databases(id) ON DELETE CASCADE,
            title TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS generic_values (
            record_id INTEGER NOT NULL REFERENCES generic_records(id) ON DELETE CASCADE,
            property_id INTEGER NOT NULL REFERENCES generic_properties(id) ON DELETE CASCADE,
            value_json TEXT NOT NULL DEFAULT 'null',
            PRIMARY KEY(record_id, property_id)
          )
        ''');
        await database.customStatement(
          'CREATE INDEX IF NOT EXISTS generic_databases_workspace_idx '
          'ON generic_databases(workspace_id, sort_order, id)',
        );
        await database.customStatement(
          'CREATE INDEX IF NOT EXISTS generic_properties_database_idx '
          'ON generic_properties(database_id, sort_order, id)',
        );
        await database.customStatement(
          'CREATE INDEX IF NOT EXISTS generic_records_database_idx '
          'ON generic_records(database_id, updated_at DESC, id DESC)',
        );
      });

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_, stackTrace) {
      // Property configuration can contain user-entered options/expressions.
      // Keep the established empty fallback without logging persisted content.
      _debugJsonFallback('property config', stackTrace);
      return <String, dynamic>{};
    }
  }

  dynamic _decodeValue(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_, stackTrace) {
      // Record values are user data. Preserve the established null fallback and
      // expose only a generic diagnostic plus stack trace in assert builds.
      _debugJsonFallback('record value', stackTrace);
      return null;
    }
  }

  Future<bool> _hasSystemObjectRegistry() async {
    await ensureSchema();
    final row = await database.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'system_object_types' LIMIT 1",
    ).getSingleOrNull();
    return row != null;
  }

  GenericDatabaseDefinitionRecord _mapDatabase(QueryRow row) =>
      GenericDatabaseDefinitionRecord(
        id: row.read<int>('id'),
        workspaceId: row.read<int>('workspace_id'),
        name: row.read<String>('name'),
        icon: row.read<String>('icon'),
        sortOrder: row.read<int>('sort_order'),
      );

  /// User-facing Database destinations. Custom Databases remain visible while
  /// selected reusable system ObjectTypes deliberately opt into the same
  /// generic Database/View navigation surface.
  Future<List<GenericDatabaseDefinitionRecord>> listDatabases(int workspaceId) async {
    await ensureSchema();
    final hasSystemRegistry = await _hasSystemObjectRegistry();
    final rows = await database.customSelect(
      hasSystemRegistry
          ? '''SELECT d.id, d.workspace_id,
                      CASE s.system_key
                        WHEN 'weblink' THEN 'Weblinks'
                        WHEN 'image' THEN 'Images'
                        WHEN 'dailyNote' THEN 'Daily Notes'
                        ELSE d.name
                      END AS name,
                      d.icon, d.sort_order
               FROM generic_databases d
               LEFT JOIN system_object_types s ON s.object_type_id = d.id
               WHERE d.workspace_id = ?
                 AND (s.object_type_id IS NULL OR s.system_key IN ('weblink', 'image', 'dailyNote'))
               ORDER BY CASE s.system_key
                          WHEN 'weblink' THEN 0
                          WHEN 'image' THEN 1
                          WHEN 'dailyNote' THEN 2
                          ELSE 3
                        END,
                        d.sort_order, d.id'''
          : '''SELECT id, workspace_id, name, icon, sort_order
               FROM generic_databases
               WHERE workspace_id = ?
               ORDER BY sort_order, id''',
      variables: [Variable<int>(workspaceId)],
    ).get();
    return rows.map(_mapDatabase).toList();
  }

  /// All storage-backed ObjectTypes, including built-in system types.
  Future<List<GenericDatabaseDefinitionRecord>> listAllDatabases(int workspaceId) async {
    await ensureSchema();
    final rows = await database.customSelect(
      '''SELECT id, workspace_id, name, icon, sort_order
         FROM generic_databases
         WHERE workspace_id = ?
         ORDER BY sort_order, id''',
      variables: [Variable<int>(workspaceId)],
    ).get();
    return rows.map(_mapDatabase).toList();
  }

  Future<GenericDatabaseDefinitionRecord?> getDatabase(int id) async {
    await ensureSchema();
    final row = await database.customSelect(
      '''SELECT id, workspace_id, name, icon, sort_order
         FROM generic_databases WHERE id = ? LIMIT 1''',
      variables: [Variable<int>(id)],
    ).getSingleOrNull();
    return row == null ? null : _mapDatabase(row);
  }

  Future<int> createDatabase({
    required int workspaceId,
    required String name,
    String icon = '🗃️',
  }) async {
    await ensureSchema();
    final existing = await listAllDatabases(workspaceId);
    final order = existing.isEmpty
        ? 0
        : existing.map((item) => item.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final normalizedName =
        name.trim().isEmpty ? '新しいデータベース' : name.trim();
    return database.customInsert(
      'INSERT INTO generic_databases(workspace_id, name, icon, sort_order) VALUES (?, ?, ?, ?)',
      variables: [
        Variable<int>(workspaceId),
        Variable<String>(normalizedName),
        Variable<String>(icon),
        Variable<int>(order),
      ],
    );
  }

  Future<void> renameDatabase(int id, String name) async {
    final value = name.trim();
    if (value.isEmpty) return;
    await ensureSchema();
    await database.customStatement('UPDATE generic_databases SET name = ? WHERE id = ?', [value, id]);
  }

  Future<void> setDatabaseIcon(int id, String icon) async {
    await ensureSchema();
    await database.customStatement('UPDATE generic_databases SET icon = ? WHERE id = ?', [icon, id]);
  }

  Future<void> deleteDatabase(int id) async {
    await ensureSchema();
    await database.customStatement('DELETE FROM generic_databases WHERE id = ?', [id]);
  }

  Future<void> reorderDatabases(List<int> ids) async {
    await ensureSchema();
    await database.transaction(() async {
      for (var index = 0; index < ids.length; index++) {
        await database.customStatement(
          'UPDATE generic_databases SET sort_order = ? WHERE id = ?',
          [index, ids[index]],
        );
      }
    });
  }

  Future<List<GenericPropertyRecord>> listProperties(int databaseId) async {
    await ensureSchema();
    final rows = await database.customSelect(
      '''SELECT id, database_id, name, type, config_json, sort_order
         FROM generic_properties
         WHERE database_id = ?
         ORDER BY sort_order, id''',
      variables: [Variable<int>(databaseId)],
    ).get();
    return rows
        .map(
          (row) => GenericPropertyRecord(
            id: row.read<int>('id'),
            databaseId: row.read<int>('database_id'),
            name: row.read<String>('name'),
            type: row.read<String>('type'),
            config: _decodeMap(row.read<String>('config_json')),
            sortOrder: row.read<int>('sort_order'),
          ),
        )
        .toList();
  }

  Future<int> createProperty({
    required int databaseId,
    required String name,
    required String type,
    Map<String, dynamic> config = const {},
  }) async {
    await ensureSchema();
    final properties = await listProperties(databaseId);
    final order = properties.isEmpty
        ? 0
        : properties.map((item) => item.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    return database.customInsert(
      '''INSERT INTO generic_properties(database_id, name, type, config_json, sort_order)
         VALUES (?, ?, ?, ?, ?)''',
      variables: [
        Variable<int>(databaseId),
        Variable<String>(name.trim()),
        Variable<String>(type),
        Variable<String>(jsonEncode(config)),
        Variable<int>(order),
      ],
    );
  }

  Future<void> updateProperty(GenericPropertyRecord property) async {
    await ensureSchema();
    await database.customStatement(
      '''UPDATE generic_properties
         SET name = ?, type = ?, config_json = ?, sort_order = ?
         WHERE id = ?''',
      [property.name, property.type, jsonEncode(property.config), property.sortOrder, property.id],
    );
  }

  Future<void> deleteProperty(int id) async {
    await ensureSchema();
    await database.customStatement('DELETE FROM generic_properties WHERE id = ?', [id]);
  }

  Future<void> reorderProperties(List<GenericPropertyRecord> properties) async {
    await ensureSchema();
    await database.transaction(() async {
      for (var index = 0; index < properties.length; index++) {
        await database.customStatement(
          'UPDATE generic_properties SET sort_order = ? WHERE id = ?',
          [index, properties[index].id],
        );
      }
    });
  }

  Future<List<GenericRecord>> listRecords(int databaseId) async {
    await ensureSchema();
    final recordRows = await database.customSelect(
      '''SELECT id, database_id, title, created_at, updated_at
         FROM generic_records
         WHERE database_id = ?
         ORDER BY updated_at DESC, id DESC''',
      variables: [Variable<int>(databaseId)],
    ).get();
    if (recordRows.isEmpty) return const [];
    final ids = recordRows.map((row) => row.read<int>('id')).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final valueRows = await database.customSelect(
      'SELECT record_id, property_id, value_json FROM generic_values WHERE record_id IN ($placeholders)',
      variables: ids.map((id) => Variable<int>(id)).toList(),
    ).get();
    final valuesByRecord = <int, Map<int, dynamic>>{};
    for (final row in valueRows) {
      final recordId = row.read<int>('record_id');
      final propertyId = row.read<int>('property_id');
      valuesByRecord.putIfAbsent(recordId, () => <int, dynamic>{})[propertyId] =
          _decodeValue(row.read<String>('value_json'));
    }
    DateTime parseTime(String value) => DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    return recordRows
        .map(
          (row) => GenericRecord(
            id: row.read<int>('id'),
            databaseId: row.read<int>('database_id'),
            title: row.read<String>('title'),
            createdAt: parseTime(row.read<String>('created_at')),
            updatedAt: parseTime(row.read<String>('updated_at')),
            values: valuesByRecord[row.read<int>('id')] ?? const {},
          ),
        )
        .toList();
  }

  Future<int> createRecord({required int databaseId, required String title}) async {
    await ensureSchema();
    final normalizedTitle = title.trim().isEmpty ? '新規ページ' : title.trim();
    return database.customInsert(
      'INSERT INTO generic_records(database_id, title) VALUES (?, ?)',
      variables: [
        Variable<int>(databaseId),
        Variable<String>(normalizedTitle),
      ],
    );
  }

  Future<void> renameRecord(int id, String title) async {
    final value = title.trim();
    if (value.isEmpty) return;
    await ensureSchema();
    await database.customStatement(
      'UPDATE generic_records SET title = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [value, id],
    );
  }

  Future<void> deleteRecord(int id) async {
    await ensureSchema();
    await database.customStatement('DELETE FROM generic_records WHERE id = ?', [id]);
  }

  Future<void> setValue({
    required int recordId,
    required int propertyId,
    required dynamic value,
  }) async {
    await ensureSchema();
    final ownership = await database.customSelect(
      '''SELECT
           (SELECT database_id FROM generic_records WHERE id = ? LIMIT 1)
             AS record_database_id,
           (SELECT database_id FROM generic_properties WHERE id = ? LIMIT 1)
             AS property_database_id,
           (SELECT config_json FROM generic_properties WHERE id = ? LIMIT 1)
             AS property_config_json,
           EXISTS(
             SELECT 1 FROM generic_values
             WHERE record_id = ? AND property_id = ?
           ) AS value_exists''',
      variables: [
        Variable<int>(recordId),
        Variable<int>(propertyId),
        Variable<int>(propertyId),
        Variable<int>(recordId),
        Variable<int>(propertyId),
      ],
    ).getSingle();
    final recordDatabaseId = ownership.readNullable<int>('record_database_id');
    final propertyDatabaseId = ownership.readNullable<int>('property_database_id');
    if (recordDatabaseId == null) {
      throw ArgumentError.value(
        recordId,
        'recordId',
        'Record does not exist.',
      );
    }
    if (propertyDatabaseId == null) {
      throw ArgumentError.value(
        propertyId,
        'propertyId',
        'Property does not exist.',
      );
    }
    if (recordDatabaseId != propertyDatabaseId) {
      throw ArgumentError.value(
        propertyId,
        'propertyId',
        'Property belongs to ObjectType $propertyDatabaseId, not Record ObjectType $recordDatabaseId.',
      );
    }

    final propertyConfigRaw =
        ownership.readNullable<String>('property_config_json');
    final valueExists = ownership.read<int>('value_exists') != 0;
    if (valueExists &&
        propertyConfigRaw != null &&
        ObjectPropertyDefinition.isIdentityManagedConfig(
          _decodeMap(propertyConfigRaw),
        )) {
      // Identity-managed Values are initialized by their owning lifecycle
      // service and then remain stable. Generic Table/Value writers consume
      // the same metadata contract as Object detail editing and cannot split a
      // stored identity field from its registry/owner state. Returning before
      // the transaction also keeps updated_at unchanged for the rejected edit.
      return;
    }

    await database.transaction(() async {
      await database.customStatement(
        '''INSERT INTO generic_values(record_id, property_id, value_json)
           VALUES (?, ?, ?)
           ON CONFLICT(record_id, property_id)
           DO UPDATE SET value_json = excluded.value_json''',
        [recordId, propertyId, jsonEncode(value)],
      );
      await database.customStatement(
        'UPDATE generic_records SET updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [recordId],
      );
    });
  }
}
