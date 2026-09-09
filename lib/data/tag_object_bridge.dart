import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';
import 'system_object_store.dart';
import 'tag_hierarchy_integrity_service.dart';

class TagObjectSchema {
  const TagObjectSchema({
    required this.objectType,
    required this.tagGroupObjectType,
    required this.parentProperty,
    required this.groupProperty,
    required this.legacyTagIdProperty,
    required this.legacyTagGroupIdProperty,
    required this.groupIdProperty,
  });

  final AppObjectType objectType;
  final AppObjectType tagGroupObjectType;
  final ObjectPropertyDefinition parentProperty;
  final ObjectPropertyDefinition groupProperty;
  final ObjectPropertyDefinition legacyTagIdProperty;
  final ObjectPropertyDefinition legacyTagGroupIdProperty;
  final ObjectPropertyDefinition groupIdProperty;
}

class TagObjectBridge {
  TagObjectBridge({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
  }) {
    final genericStore = GenericDatabaseStore(database);
    _relationMutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
    );
    _hierarchyIntegrity = TagHierarchyIntegrityService(
      objectStore: objectStore,
      relationMutations: _relationMutations,
    );
  }

  static const systemKey = 'tag';
  static const tagGroupSystemKey = 'tag_group';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  late final RelationMutationService _relationMutations;
  late final TagHierarchyIntegrityService _hierarchyIntegrity;
  Future<void>? _schemaReady;

  TagHierarchyIntegrityService get hierarchyIntegrity => _hierarchyIntegrity;

  Future<void> ensureSchema() => _schemaReady ??= database.transaction(() async {
        await systemObjectStore.ensureSchema();
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS tag_object_links (
            workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
            tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
            object_id INTEGER NOT NULL REFERENCES generic_records(id) ON DELETE CASCADE,
            PRIMARY KEY(workspace_id, tag_id),
            UNIQUE(workspace_id, object_id)
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
    final tagGroupType = await systemObjectStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: tagGroupSystemKey,
      name: 'タググループ',
      icon: '🗂️',
    );
    final legacyTagId = await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Legacy Tag ID',
      type: ObjectPropertyType.number,
      config: const {'system': true, 'hidden': true},
    );
    final legacyTagGroupId = await systemObjectStore.ensureProperty(
      objectTypeId: tagGroupType.id,
      name: 'Legacy TagGroup ID',
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
    final group = await systemObjectStore.ensureRelationProperty(
      objectTypeId: type.id,
      name: 'Group',
      targetObjectTypeId: tagGroupType.id,
      multiple: false,
    );
    final refreshed = (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;
    final refreshedTagGroup = (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: tagGroupSystemKey,
    ))!;
    return TagObjectSchema(
      objectType: refreshed,
      tagGroupObjectType: refreshedTagGroup,
      parentProperty: refreshed.properties.firstWhere(
        (property) => property.id == parent.id,
      ),
      groupProperty: refreshed.properties.firstWhere(
        (property) => property.id == group.id,
      ),
      legacyTagIdProperty: refreshed.properties.firstWhere(
        (property) => property.id == legacyTagId.id,
      ),
      legacyTagGroupIdProperty: refreshedTagGroup.properties.firstWhere(
        (property) => property.id == legacyTagGroupId.id,
      ),
      groupIdProperty: refreshed.properties.firstWhere(
        (property) => property.id == groupId.id,
      ),
    );
  }

  Future<void> syncLegacyTags(int workspaceId) async {
    final schema = await ensureTagObjectType(workspaceId);
    await database.transaction(
      () => _syncLegacyTagProjection(
        workspaceId: workspaceId,
        schema: schema,
      ),
    );
  }

  /// Creates a legacy Tag and its canonical Tag Object projection atomically.
  ///
  /// Schema provisioning happens before the transaction. Once projection starts,
  /// the legacy Tag row, Tag Object/link, metadata, Parent Relation, and orphan
  /// cleanup either all commit or all roll back together.
  Future<int> createLegacyTagObject({
    required int workspaceId,
    required String name,
  }) async {
    final schema = await ensureTagObjectType(workspaceId);
    return database.transaction(() async {
      final tagId = await database.createTag(name);
      await _syncLegacyTagProjection(
        workspaceId: workspaceId,
        schema: schema,
      );
      final objectId = await objectIdForLegacyTag(workspaceId, tagId);
      if (objectId == null) {
        throw StateError('Canonical Tag Object was not created after Tag sync.');
      }
      return objectId;
    });
  }

  Future<void> _syncLegacyTagProjection({
    required int workspaceId,
    required TagObjectSchema schema,
  }) async {
    final groups = await database.select(database.tagGroups).get();
    final validGroupIds = groups.map((group) => group.id).toSet();
    for (final group in groups) {
      final objectId = await _ensureObjectForTagGroup(
        schema: schema,
        group: group,
      );
      await objectStore.renameObject(objectId, group.name);
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: schema.legacyTagGroupIdProperty,
        value: group.id,
      );
    }

    final tags = await database.select(database.tags).get();
    final validTagIds = tags.map((tag) => tag.id).toSet();
    for (final tag in tags) {
      final objectId = await _ensureObjectForTag(workspaceId, schema, tag);
      await objectStore.renameObject(objectId, tag.name);
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: schema.legacyTagIdProperty,
        value: tag.id,
      );
      // Keep the pre-Object group id as compatibility metadata while canonical
      // Object-first group membership is mirrored through Tag -> TagGroup.
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: schema.groupIdProperty,
        value: tag.groupId,
      );
    }

    for (final tag in tags) {
      final objectId = await objectIdForLegacyTag(workspaceId, tag.id);
      if (objectId == null) continue;
      final parentObjectId = tag.parentTagId == null
          ? null
          : await objectIdForLegacyTag(workspaceId, tag.parentTagId!);
      if (tag.parentTagId != null && parentObjectId == null) {
        throw StateError(
          'Legacy Tag ${tag.id} references a Parent that has no canonical Tag Object.',
        );
      }
      final groupObjectId = tag.groupId == null
          ? null
          : await _objectIdForLegacyTagGroup(schema, tag.groupId!);
      if (tag.groupId != null && groupObjectId == null) {
        throw StateError(
          'Legacy Tag ${tag.id} references a TagGroup that has no canonical Object.',
        );
      }
      await _hierarchyIntegrity.setParent(
        workspaceId: workspaceId,
        tagObjectId: objectId,
        parentProperty: schema.parentProperty,
        parentTagObjectId: parentObjectId,
      );
      await _hierarchyIntegrity.setGroup(
        workspaceId: workspaceId,
        tagObjectId: objectId,
        groupProperty: schema.groupProperty,
        tagGroupObjectId: groupObjectId,
      );
    }

    await _removeOrphanTagObjects(workspaceId, schema, validTagIds);
    await _removeOrphanTagGroupObjects(workspaceId, schema, validGroupIds);
  }

  Future<int?> objectIdForLegacyTag(int workspaceId, int tagId) async {
    await ensureSchema();
    final row = await database.customSelect(
      'SELECT object_id FROM tag_object_links '
      'WHERE workspace_id = ? AND tag_id = ? LIMIT 1',
      variables: [Variable<int>(workspaceId), Variable<int>(tagId)],
    ).getSingleOrNull();
    return row?.read<int>('object_id');
  }

  Future<int?> objectIdForLegacyTagGroup(int workspaceId, int groupId) async {
    final schema = await ensureTagObjectType(workspaceId);
    return _objectIdForLegacyTagGroup(schema, groupId);
  }

  Future<int?> legacyTagIdForObject(int workspaceId, int objectId) async {
    await ensureSchema();
    final row = await database.customSelect(
      'SELECT tag_id FROM tag_object_links '
      'WHERE workspace_id = ? AND object_id = ? LIMIT 1',
      variables: [Variable<int>(workspaceId), Variable<int>(objectId)],
    ).getSingleOrNull();
    return row?.read<int>('tag_id');
  }

  Future<int> _ensureObjectForTag(
    int workspaceId,
    TagObjectSchema schema,
    Tag tag,
  ) async {
    final existing = await objectIdForLegacyTag(workspaceId, tag.id);
    if (existing != null) return existing;
    final objectId = await objectStore.createObject(
      objectTypeId: schema.objectType.id,
      title: tag.name,
    );
    await database.customStatement(
      'INSERT INTO tag_object_links(workspace_id, tag_id, object_id) VALUES (?, ?, ?)',
      [workspaceId, tag.id, objectId],
    );
    return objectId;
  }

  Future<int> _ensureObjectForTagGroup({
    required TagObjectSchema schema,
    required TagGroupRecord group,
  }) async {
    final existing = await _objectIdForLegacyTagGroup(schema, group.id);
    if (existing != null) return existing;
    return objectStore.createObject(
      objectTypeId: schema.tagGroupObjectType.id,
      title: group.name,
    );
  }

  Future<int?> _objectIdForLegacyTagGroup(
    TagObjectSchema schema,
    int groupId,
  ) async {
    final objects = await objectStore.listObjects(schema.tagGroupObjectType.id);
    final matches = objects
        .where((object) {
          final rawId = object.values[schema.legacyTagGroupIdProperty.id];
          final legacyId = rawId is int ? rawId : int.tryParse('$rawId');
          return legacyId == groupId;
        })
        .toList(growable: false);
    if (matches.length > 1) {
      throw StateError(
        'Multiple canonical TagGroup Objects map to legacy TagGroup $groupId.',
      );
    }
    return matches.isEmpty ? null : matches.single.id;
  }

  Future<void> _removeOrphanTagObjects(
    int workspaceId,
    TagObjectSchema schema,
    Set<int> validTagIds,
  ) async {
    final objects = await objectStore.listObjects(schema.objectType.id);
    for (final object in objects) {
      final rawId = object.values[schema.legacyTagIdProperty.id];
      final legacyId = rawId is int ? rawId : int.tryParse('$rawId');
      if (legacyId == null || validTagIds.contains(legacyId)) continue;
      await _relationMutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: schema.objectType.id,
        objectId: object.id,
      );
    }
  }

  Future<void> _removeOrphanTagGroupObjects(
    int workspaceId,
    TagObjectSchema schema,
    Set<int> validGroupIds,
  ) async {
    final objects = await objectStore.listObjects(schema.tagGroupObjectType.id);
    for (final object in objects) {
      final rawId = object.values[schema.legacyTagGroupIdProperty.id];
      final legacyId = rawId is int ? rawId : int.tryParse('$rawId');
      if (legacyId == null || validGroupIds.contains(legacyId)) continue;
      await _relationMutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: schema.tagGroupObjectType.id,
        objectId: object.id,
      );
    }
  }
}
