import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'object_store.dart';
import 'system_object_store.dart';

class TagObjectSchema {
  const TagObjectSchema({
    required this.objectType,
    required this.parentProperty,
    required this.legacyTagIdProperty,
    required this.groupIdProperty,
  });

  final AppObjectType objectType;
  final ObjectPropertyDefinition parentProperty;
  final ObjectPropertyDefinition legacyTagIdProperty;
  final ObjectPropertyDefinition groupIdProperty;
}

class TagObjectBridge {
  TagObjectBridge({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
  });

  static const systemKey = 'tag';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??= database.transaction(() async {
        await systemObjectStore.ensureSchema();
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS tag_object_links (
            tag_id INTEGER PRIMARY KEY REFERENCES tags(id) ON DELETE CASCADE,
            object_id INTEGER NOT NULL UNIQUE REFERENCES generic_records(id) ON DELETE CASCADE
          )
        ''');
      });

  Future<TagObjectSchema> ensureTagObjectType(int workspaceId) async {
    await ensureSchema();
    final type = await systemObjectStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
      name: 'タグ',
      icon: '🏷️',
    );
    final legacyTagId = await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Legacy Tag ID',
      type: ObjectPropertyType.number,
      config: const {'system': true, 'hidden': true},
    );
    final groupId = await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Group ID',
      type: ObjectPropertyType.number,
      config: const {'system': true, 'hidden': true},
    );
    final parent = await systemObjectStore.ensureRelationProperty(
      objectTypeId: type.id,
      name: 'Parent',
      targetObjectTypeId: type.id,
      multiple: false,
    );
    final refreshed = (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;
    return TagObjectSchema(
      objectType: refreshed,
      parentProperty: refreshed.properties.firstWhere((property) => property.id == parent.id),
      legacyTagIdProperty: refreshed.properties.firstWhere((property) => property.id == legacyTagId.id),
      groupIdProperty: refreshed.properties.firstWhere((property) => property.id == groupId.id),
    );
  }

  Future<void> syncLegacyTags(int workspaceId) async {
    final schema = await ensureTagObjectType(workspaceId);
    final tags = await database.select(database.tags).get();

    for (final tag in tags) {
      final objectId = await _ensureObjectForTag(schema, tag);
      await objectStore.renameObject(objectId, tag.name);
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: schema.legacyTagIdProperty,
        value: tag.id,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: schema.groupIdProperty,
        value: tag.groupId,
      );
    }

    for (final tag in tags) {
      final objectId = await objectIdForLegacyTag(tag.id);
      if (objectId == null) continue;
      final parentObjectId = tag.parentTagId == null
          ? null
          : await objectIdForLegacyTag(tag.parentTagId!);
      await objectStore.setRelation(
        objectId: objectId,
        property: schema.parentProperty,
        targetObjectIds: parentObjectId == null ? const [] : [parentObjectId],
      );
    }
  }

  Future<int?> objectIdForLegacyTag(int tagId) async {
    await ensureSchema();
    final row = await database.customSelect(
      'SELECT object_id FROM tag_object_links WHERE tag_id = ? LIMIT 1',
      variables: [Variable<int>(tagId)],
    ).getSingleOrNull();
    return row?.read<int>('object_id');
  }

  Future<int?> legacyTagIdForObject(int objectId) async {
    await ensureSchema();
    final row = await database.customSelect(
      'SELECT tag_id FROM tag_object_links WHERE object_id = ? LIMIT 1',
      variables: [Variable<int>(objectId)],
    ).getSingleOrNull();
    return row?.read<int>('tag_id');
  }

  Future<int> _ensureObjectForTag(TagObjectSchema schema, Tag tag) async {
    final existing = await objectIdForLegacyTag(tag.id);
    if (existing != null) return existing;
    final objectId = await objectStore.createObject(
      objectTypeId: schema.objectType.id,
      title: tag.name,
    );
    await database.customStatement(
      'INSERT INTO tag_object_links(tag_id, object_id) VALUES (?, ?)',
      [tag.id, objectId],
    );
    return objectId;
  }
}
