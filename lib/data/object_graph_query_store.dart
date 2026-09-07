import 'package:drift/drift.dart';

import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_read_service.dart';

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
    final target = await getNode(targetObjectId);
    if (target == null) return const <ObjectGraphBacklinkRecord>[];

    final objectStore = ObjectStore(store);
    final resolved = await RelationReadService(objectStore).backlinks(
      workspaceId: target.workspaceId,
      targetObjectId: targetObjectId,
    );
    if (resolved.isEmpty) return const <ObjectGraphBacklinkRecord>[];

    final objectTypes = await objectStore.listObjectTypes(target.workspaceId);
    final objectTypesById = {
      for (final objectType in objectTypes) objectType.id: objectType,
    };
    final result = <ObjectGraphBacklinkRecord>[];
    for (final backlink in resolved) {
      final sourceType = objectTypesById[backlink.sourceObject.objectTypeId];
      if (sourceType == null) continue;
      result.add(
        ObjectGraphBacklinkRecord(
          sourceObjectId: backlink.sourceObject.id,
          sourceObjectTypeId: backlink.sourceObject.objectTypeId,
          sourceTitle: backlink.sourceObject.title,
          sourceObjectTypeName: sourceType.name,
          sourceObjectTypeIcon: sourceType.icon,
          propertyId: backlink.property.id,
          propertyName: backlink.property.name,
        ),
      );
    }
    result.sort(_compareBacklinks);
    return result;
  }

  static int _compareBacklinks(
    ObjectGraphBacklinkRecord left,
    ObjectGraphBacklinkRecord right,
  ) {
    var compared = left.sourceObjectTypeName.toLowerCase().compareTo(
      right.sourceObjectTypeName.toLowerCase(),
    );
    if (compared != 0) return compared;
    compared = left.sourceTitle.toLowerCase().compareTo(
      right.sourceTitle.toLowerCase(),
    );
    if (compared != 0) return compared;
    return left.propertyName.toLowerCase().compareTo(
      right.propertyName.toLowerCase(),
    );
  }

  Future<bool> _hasSystemRegistry() async {
    final row = await store.database.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'system_object_types' LIMIT 1",
    ).getSingleOrNull();
    return row != null;
  }
}
