import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'object_store.dart';

class SystemObjectStore {
  SystemObjectStore({
    required this.database,
    required this.objectStore,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??= database.transaction(() async {
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS system_object_types (
            object_type_id INTEGER PRIMARY KEY
              REFERENCES generic_databases(id) ON DELETE CASCADE,
            workspace_id INTEGER NOT NULL
              REFERENCES workspaces(id) ON DELETE CASCADE,
            system_key TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(workspace_id, system_key)
          )
        ''');
        await database.customStatement(
          'CREATE INDEX IF NOT EXISTS system_object_types_workspace_idx '
          'ON system_object_types(workspace_id, system_key)',
        );
      });

  Future<AppObjectType> ensureSystemObjectType({
    required int workspaceId,
    required String systemKey,
    required String name,
    required String icon,
  }) async {
    await ensureSchema();
    final existing = await getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    );
    if (existing != null) return existing;

    final id = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: name,
      icon: icon,
    );
    await database.customStatement(
      '''INSERT INTO system_object_types(object_type_id, workspace_id, system_key)
         VALUES (?, ?, ?)''',
      [id, workspaceId, systemKey],
    );
    return (await getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;
  }

  Future<AppObjectType?> getSystemObjectType({
    required int workspaceId,
    required String systemKey,
  }) async {
    await ensureSchema();
    final row = await database.customSelect(
      '''SELECT object_type_id FROM system_object_types
         WHERE workspace_id = ? AND system_key = ? LIMIT 1''',
      variables: [Variable<int>(workspaceId), Variable<String>(systemKey)],
    ).getSingleOrNull();
    if (row == null) return null;
    final base = await objectStore.getObjectType(row.read<int>('object_type_id'));
    if (base == null) return null;
    return AppObjectType(
      id: base.id,
      workspaceId: base.workspaceId,
      name: base.name,
      icon: base.icon,
      kind: ObjectTypeKind.system,
      sortOrder: base.sortOrder,
      properties: base.properties,
    );
  }

  Future<String?> systemKeyForObjectType(int objectTypeId) async {
    await ensureSchema();
    final row = await database.customSelect(
      'SELECT system_key FROM system_object_types WHERE object_type_id = ? LIMIT 1',
      variables: [Variable<int>(objectTypeId)],
    ).getSingleOrNull();
    return row?.read<String>('system_key');
  }

  Future<ObjectPropertyDefinition> ensureProperty({
    required int objectTypeId,
    required String name,
    required ObjectPropertyType type,
    Map<String, dynamic> config = const <String, dynamic>{},
  }) async {
    final current = await objectStore.getObjectType(objectTypeId);
    if (current == null) {
      throw ArgumentError.value(objectTypeId, 'objectTypeId', 'Object type does not exist.');
    }
    for (final property in current.properties) {
      if (property.name == name) return property;
    }
    final id = await objectStore.createProperty(
      objectTypeId: objectTypeId,
      name: name,
      type: type,
      config: config,
      allowSystemMutation: true,
    );
    final refreshed = (await objectStore.getObjectType(objectTypeId))!;
    return refreshed.properties.firstWhere((property) => property.id == id);
  }

  Future<ObjectPropertyDefinition> ensureRelationProperty({
    required int objectTypeId,
    required String name,
    required int targetObjectTypeId,
    bool multiple = true,
  }) {
    return ensureProperty(
      objectTypeId: objectTypeId,
      name: name,
      type: ObjectPropertyType.objectRelation,
      config: <String, dynamic>{
        'targetObjectTypeId': targetObjectTypeId,
        'multiple': multiple,
      },
    );
  }
}
