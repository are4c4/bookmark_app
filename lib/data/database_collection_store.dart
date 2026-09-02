import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/database_collection_definition.dart';
import '../domain/object_model.dart';
import '../domain/object_query.dart';
import 'generic_database_store.dart';
import 'object_store.dart';

/// Additive persistence for Database-level Object collection semantics.
///
/// This storage is deliberately separate from `DatabaseViewConfig`: collection
/// filters decide which Objects belong to a Database, while View filters only
/// narrow/present that collection.
class DatabaseCollectionStore {
  DatabaseCollectionStore({
    required this.genericStore,
    required this.objectStore,
  });

  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??=
      genericStore.database.transaction(() async {
        await genericStore.ensureSchema();
        await genericStore.database.customStatement('''
          CREATE TABLE IF NOT EXISTS database_collection_definitions (
            database_id INTEGER PRIMARY KEY
              REFERENCES generic_databases(id) ON DELETE CASCADE,
            target_object_type_id INTEGER NOT NULL
              REFERENCES generic_databases(id) ON DELETE RESTRICT,
            collection_filter_json TEXT NOT NULL DEFAULT '[]',
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      });

  /// Reads explicit collection semantics, or the backward-compatible legacy
  /// interpretation when the Database has not been configured yet.
  Future<DatabaseCollectionDefinition?> readEffective(int databaseId) async {
    await ensureSchema();
    final database = await genericStore.getDatabase(databaseId);
    if (database == null) return null;

    final row = await genericStore.database.customSelect(
      '''SELECT target_object_type_id, collection_filter_json
         FROM database_collection_definitions
         WHERE database_id = ? LIMIT 1''',
      variables: [Variable<int>(databaseId)],
    ).getSingleOrNull();

    if (row == null) {
      return DatabaseCollectionDefinition(
        databaseId: database.id,
        workspaceId: database.workspaceId,
        targetObjectTypeId: database.id,
        isLegacyFallback: true,
      );
    }

    final targetObjectTypeId = row.read<int>('target_object_type_id');
    final target = await objectStore.getObjectType(targetObjectTypeId);
    if (target == null || target.workspaceId != database.workspaceId) {
      throw StateError(
        'Stored Database collection target is missing or belongs to another workspace.',
      );
    }

    return DatabaseCollectionDefinition(
      databaseId: database.id,
      workspaceId: database.workspaceId,
      targetObjectTypeId: targetObjectTypeId,
      collectionFilter: _decodeFilters(
        row.read<String>('collection_filter_json'),
      ),
    );
  }

  Future<void> write(DatabaseCollectionDefinition definition) async {
    await ensureSchema();
    final database = await genericStore.getDatabase(definition.databaseId);
    if (database == null || database.workspaceId != definition.workspaceId) {
      throw ArgumentError.value(
        definition.databaseId,
        'definition',
        'Database must exist in the supplied workspace.',
      );
    }
    final target = await objectStore.getObjectType(definition.targetObjectTypeId);
    if (target == null || target.workspaceId != definition.workspaceId) {
      throw ArgumentError.value(
        definition.targetObjectTypeId,
        'definition',
        'Target ObjectType must exist in the same workspace as the Database.',
      );
    }
    _validateFilterPropertyIds(definition.collectionFilter, target);

    await genericStore.database.customStatement(
      '''INSERT INTO database_collection_definitions(
           database_id, target_object_type_id, collection_filter_json, updated_at
         ) VALUES (?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(database_id)
         DO UPDATE SET
           target_object_type_id = excluded.target_object_type_id,
           collection_filter_json = excluded.collection_filter_json,
           updated_at = CURRENT_TIMESTAMP''',
      [
        definition.databaseId,
        definition.targetObjectTypeId,
        jsonEncode(
          definition.collectionFilter
              .map((rule) => rule.toJson())
              .toList(growable: false),
        ),
      ],
    );
  }

  /// Removes explicit semantics and restores the legacy self-type/all-Objects
  /// behavior without deleting the Database or any Object.
  Future<void> clear(int databaseId) async {
    await ensureSchema();
    await genericStore.database.customStatement(
      'DELETE FROM database_collection_definitions WHERE database_id = ?',
      [databaseId],
    );
  }

  List<ObjectFilterRule> _decodeFilters(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Stored Database collection filter is invalid JSON.');
    }
    if (decoded is! List) {
      throw const FormatException('Stored Database collection filter must be a list.');
    }
    final rules = <ObjectFilterRule>[];
    for (final item in decoded) {
      final rule = ObjectFilterRule.fromJson(item);
      if (rule == null) {
        throw const FormatException('Stored Database collection filter contains an invalid rule.');
      }
      rules.add(rule);
    }
    return List<ObjectFilterRule>.unmodifiable(rules);
  }

  void _validateFilterPropertyIds(
    List<ObjectFilterRule> rules,
    AppObjectType target,
  ) {
    final propertyIds = target.properties.map((property) => property.id).toSet();
    for (final rule in rules) {
      final propertyId = rule.propertyId;
      if (propertyId != null && !propertyIds.contains(propertyId)) {
        throw ArgumentError.value(
          propertyId,
          'definition',
          'Collection filter Property must belong to the target ObjectType.',
        );
      }
    }
  }
}
