import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';
import 'system_object_store.dart';
import 'tag_hierarchy_integrity_service.dart';

class TagObjectSchema {
  const TagObjectSchema({
    required this.objectType,
    required this.tagGroupObjectType,
    required this.parentProperty,
    required this.groupProperty,
    required this.legacyTagIdProperty,
    required this.legacyParentTagIdProperty,
    required this.legacyTagGroupIdProperty,
    required this.groupIdProperty,
  });

  final AppObjectType objectType;
  final AppObjectType tagGroupObjectType;
  final ObjectPropertyDefinition parentProperty;
  final ObjectPropertyDefinition groupProperty;
  final ObjectPropertyDefinition legacyTagIdProperty;
  final ObjectPropertyDefinition legacyParentTagIdProperty;
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
    final legacyParentTagId = await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Legacy Parent Tag ID',
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
      legacyParentTagIdProperty: refreshed.properties.firstWhere(
        (property) => property.id == legacyParentTagId.id,
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
    for (final group in groups) {
      final existingObjectId = await _objectIdForLegacyTagGroup(
        schema,
        group.id,
      );
      final objectId =
          existingObjectId ??
          await _ensureObjectForTagGroup(schema: schema, group: group);
      if (existingObjectId == null) {
        await objectStore.setPropertyValue(
          objectId: objectId,
          property: schema.legacyTagGroupIdProperty,
          value: group.id,
        );
      }
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

      await _reconcileLegacyRelation(
        workspaceId: workspaceId,
        sourceObjectId: objectId,
        relationProperty: schema.parentProperty,
        checkpointProperty: schema.legacyParentTagIdProperty,
        targetLegacyIdProperty: schema.legacyTagIdProperty,
        currentLegacyId: tag.parentTagId,
        currentLegacyTargetObjectId: parentObjectId,
        label: 'Parent',
        applyLegacyTarget: () => _hierarchyIntegrity.setParent(
          workspaceId: workspaceId,
          tagObjectId: objectId,
          parentProperty: schema.parentProperty,
          parentTagObjectId: parentObjectId,
        ),
      );
      await _reconcileLegacyRelation(
        workspaceId: workspaceId,
        sourceObjectId: objectId,
        relationProperty: schema.groupProperty,
        checkpointProperty: schema.groupIdProperty,
        targetLegacyIdProperty: schema.legacyTagGroupIdProperty,
        currentLegacyId: tag.groupId,
        currentLegacyTargetObjectId: groupObjectId,
        label: 'Group',
        applyLegacyTarget: () => _hierarchyIntegrity.setGroup(
          workspaceId: workspaceId,
          tagObjectId: objectId,
          groupProperty: schema.groupProperty,
          tagGroupObjectId: groupObjectId,
        ),
      );
    }

    await _removeOrphanTagObjects(workspaceId, schema, validTagIds);
  }

  Future<void> _reconcileLegacyRelation({
    required int workspaceId,
    required int sourceObjectId,
    required ObjectPropertyDefinition relationProperty,
    required ObjectPropertyDefinition checkpointProperty,
    required ObjectPropertyDefinition targetLegacyIdProperty,
    required int? currentLegacyId,
    required int? currentLegacyTargetObjectId,
    required String label,
    required Future<void> Function() applyLegacyTarget,
  }) async {
    final hasCanonicalValue = await _hasStoredPropertyValue(
      objectId: sourceObjectId,
      propertyId: relationProperty.id,
    );
    final checkpoint = await _legacyCheckpoint(
      objectTypeId: relationProperty.objectTypeId,
      objectId: sourceObjectId,
      property: checkpointProperty,
    );

    if (!hasCanonicalValue) {
      await applyLegacyTarget();
      await _writeLegacyCheckpoint(
        objectId: sourceObjectId,
        property: checkpointProperty,
        value: currentLegacyId,
      );
      return;
    }

    final canonical = await _hierarchyIntegrity.relationTargets.selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: sourceObjectId,
      property: relationProperty,
    );

    if (!checkpoint.present) {
      if (!_selectionMatchesCurrentLegacy(
        canonical,
        currentLegacyId: currentLegacyId,
        currentLegacyTargetObjectId: currentLegacyTargetObjectId,
      )) {
        throw StateError(
          'Existing canonical Tag $label Relation diverges from legacy state before a reconciliation checkpoint exists.',
        );
      }
      await _writeLegacyCheckpoint(
        objectId: sourceObjectId,
        property: checkpointProperty,
        value: currentLegacyId,
      );
      return;
    }

    if (checkpoint.value == currentLegacyId) {
      // Legacy state has not changed since its last successful projection.
      // Preserve any canonical-only mutation while still strictly validating
      // the Relation value/index/targets above.
      return;
    }

    final canonicalStillMatchesCheckpoint = await _selectionMatchesCheckpoint(
      canonical,
      checkpointValue: checkpoint.value,
      targetLegacyIdProperty: targetLegacyIdProperty,
    );
    if (!canonicalStillMatchesCheckpoint) {
      throw StateError(
        'Legacy Tag $label and canonical Relation changed independently; refusing to choose an authority.',
      );
    }

    await applyLegacyTarget();
    await _writeLegacyCheckpoint(
      objectId: sourceObjectId,
      property: checkpointProperty,
      value: currentLegacyId,
    );
  }

  bool _selectionMatchesCurrentLegacy(
    RelationSelectionContext selection, {
    required int? currentLegacyId,
    required int? currentLegacyTargetObjectId,
  }) {
    if (currentLegacyId == null) return selection.selectedObjectIds.isEmpty;
    return currentLegacyTargetObjectId != null &&
        selection.selectedObjectIds.length == 1 &&
        selection.selectedObjectIds.single == currentLegacyTargetObjectId;
  }

  Future<bool> _selectionMatchesCheckpoint(
    RelationSelectionContext selection, {
    required int? checkpointValue,
    required ObjectPropertyDefinition targetLegacyIdProperty,
  }) async {
    if (selection.selectedObjectIds.isEmpty) return checkpointValue == null;
    if (selection.selectedObjectIds.length != 1) return false;
    final target = await _legacyCheckpoint(
      objectTypeId: selection.targetObjectType.id,
      objectId: selection.selectedObjectIds.single,
      property: targetLegacyIdProperty,
    );
    return target.present && target.value == checkpointValue;
  }

  Future<_LegacyCheckpoint> _legacyCheckpoint({
    required int objectTypeId,
    required int objectId,
    required ObjectPropertyDefinition property,
  }) async {
    final objects = await objectStore.listObjects(objectTypeId);
    final matches = objects.where((object) => object.id == objectId).toList();
    if (matches.length != 1) {
      throw StateError('Canonical Object $objectId is missing or ambiguous.');
    }
    final object = matches.single;
    if (!object.values.containsKey(property.id)) {
      return const _LegacyCheckpoint.absent();
    }
    final raw = object.values[property.id];
    if (raw == null) return const _LegacyCheckpoint.present(null);
    if (raw is int) return _LegacyCheckpoint.present(raw);
    if (raw is num && raw == raw.toInt()) {
      return _LegacyCheckpoint.present(raw.toInt());
    }
    final parsed = int.tryParse('$raw');
    if (parsed == null) {
      throw StateError(
        'Malformed legacy reconciliation checkpoint on Object $objectId / Property ${property.id}.',
      );
    }
    return _LegacyCheckpoint.present(parsed);
  }

  Future<void> _writeLegacyCheckpoint({
    required int objectId,
    required ObjectPropertyDefinition property,
    required int? value,
  }) => objectStore.setPropertyValue(
        objectId: objectId,
        property: property,
        value: value,
      );

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

  Future<bool> _hasStoredPropertyValue({
    required int objectId,
    required int propertyId,
  }) async {
    final row = await database
        .customSelect(
          '''SELECT 1 FROM generic_values
         WHERE record_id = ? AND property_id = ? LIMIT 1''',
          variables: [Variable<int>(objectId), Variable<int>(propertyId)],
        )
        .getSingleOrNull();
    return row != null;
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
}

class _LegacyCheckpoint {
  const _LegacyCheckpoint.absent() : present = false, value = null;
  const _LegacyCheckpoint.present(this.value) : present = true;

  final bool present;
  final int? value;
}
