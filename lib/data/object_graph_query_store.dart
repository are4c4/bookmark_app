import 'package:drift/drift.dart';

import 'generic_database_store.dart';

class ObjectGraphNodeRecord {
  const ObjectGraphNodeRecord({
    required this.objectId,
    required this.objectTypeId,
    required this.workspaceId,
    required this.title,
    required this.objectTypeName,
    required this.objectTypeIcon,
    required this.isSystemType,
  });

  final int objectId;
  final int objectTypeId;
  final int workspaceId;
  final String title;
  final String objectTypeName;
  final String objectTypeIcon;
  final bool isSystemType;
}

class ObjectGraphBacklinkRecord {
  const ObjectGraphBacklinkRecord({
    required this.sourceObjectId,
    required this.sourceObjectTypeId,
    required this.sourceTitle,
    required this.sourceObjectTypeName,
    required this.sourceObjectTypeIcon,
    required this.propertyId,
    required this.propertyName,
  });

  final int sourceObjectId;
  final int sourceObjectTypeId;
  final String sourceTitle;
  final String sourceObjectTypeName;
  final String sourceObjectTypeIcon;
  final int propertyId;
  final String propertyName;
}

class ObjectGraphQueryStore {
  ObjectGraphQueryStore(this.store);

  final GenericDatabaseStore store;

  Future<ObjectGraphNodeRecord?> getNode(int objectId) async {
    await store.ensureSchema();
    final hasSystemRegistry = await _hasSystemRegistry();
    final systemJoin = hasSystemRegistry
        ? 'LEFT JOIN system_object_types sot ON sot.object_type_id = gd.id'
        : '';
    final systemExpression = hasSystemRegistry
        ? 'CASE WHEN sot.object_type_id IS NULL THEN 0 ELSE 1 END'
        : '0';
    final row = await store.database.customSelect(
      '''SELECT gr.id AS object_id,
                gr.database_id AS object_type_id,
                gr.title AS title,
                gd.workspace_id AS workspace_id,
                gd.name AS object_type_name,
                gd.icon AS object_type_icon,
                $systemExpression AS is_system
         FROM generic_records gr
         JOIN generic_databases gd ON gd.id = gr.database_id
         $systemJoin
         WHERE gr.id = ?
         LIMIT 1''',
      variables: [Variable<int>(objectId)],
    ).getSingleOrNull();
    if (row == null) return null;
    return ObjectGraphNodeRecord(
      objectId: row.read<int>('object_id'),
      objectTypeId: row.read<int>('object_type_id'),
      workspaceId: row.read<int>('workspace_id'),
      title: row.read<String>('title'),
      objectTypeName: row.read<String>('object_type_name'),
      objectTypeIcon: row.read<String>('object_type_icon'),
      isSystemType: row.read<int>('is_system') == 1,
    );
  }

  Future<List<ObjectGraphBacklinkRecord>> backlinks(int targetObjectId) async {
    await store.ensureSchema();
    final relationIndexExists = await store.database.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'object_relation_edges' LIMIT 1",
    ).getSingleOrNull();
    if (relationIndexExists == null) return const [];

    final rows = await store.database.customSelect(
      '''SELECT edge.source_object_id AS source_object_id,
                source.database_id AS source_object_type_id,
                source.title AS source_title,
                source_type.name AS source_object_type_name,
                source_type.icon AS source_object_type_icon,
                edge.property_id AS property_id,
                property.name AS property_name
         FROM object_relation_edges edge
         JOIN generic_records source ON source.id = edge.source_object_id
         JOIN generic_databases source_type ON source_type.id = source.database_id
         JOIN generic_properties property ON property.id = edge.property_id
         WHERE edge.target_object_id = ?
         ORDER BY source_type.name COLLATE NOCASE,
                  source.title COLLATE NOCASE,
                  property.name COLLATE NOCASE''',
      variables: [Variable<int>(targetObjectId)],
    ).get();

    return rows
        .map(
          (row) => ObjectGraphBacklinkRecord(
            sourceObjectId: row.read<int>('source_object_id'),
            sourceObjectTypeId: row.read<int>('source_object_type_id'),
            sourceTitle: row.read<String>('source_title'),
            sourceObjectTypeName: row.read<String>('source_object_type_name'),
            sourceObjectTypeIcon: row.read<String>('source_object_type_icon'),
            propertyId: row.read<int>('property_id'),
            propertyName: row.read<String>('property_name'),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> _hasSystemRegistry() async {
    final row = await store.database.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'system_object_types' LIMIT 1",
    ).getSingleOrNull();
    return row != null;
  }
}
