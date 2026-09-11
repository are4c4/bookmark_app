import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'object_store.dart';
import 'tag_hierarchy_integrity_service.dart';
import 'tag_object_bridge.dart';

class TagCompatibilityMoveSnapshot {
  const TagCompatibilityMoveSnapshot({
    required this.tagId,
    required this.previousParentTagId,
    required this.previousGroupIds,
    required this.appliedParentTagId,
    required this.appliedGroupId,
  });

  final int tagId;
  final int? previousParentTagId;
  final Map<int, int?> previousGroupIds;
  final int? appliedParentTagId;
  final int? appliedGroupId;
}

/// Canonical-first transition mutations for the surviving legacy Tag UI.
///
/// Canonical Tag Parent/Group Relations remain authoritative. Each operation
/// mutates those Relations first through [TagHierarchyIntegrityService], then
/// projects the same result into retained `tags.parent_tag_id` / `tags.group_id`
/// fields and advances the reconciliation checkpoints in one transaction.
///
/// The service deliberately does not own presentation or a second hierarchy
/// store. Legacy ids are accepted only as compatibility handles and must resolve
/// unambiguously to the already-canonical Tag/TagGroup Objects.
class TagHierarchyCompatibilityMutationService {
  TagHierarchyCompatibilityMutationService({
    required this.database,
    required this.objectStore,
    required this.bridge,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final TagObjectBridge bridge;

  Future<TagCompatibilityMoveSnapshot> moveTag({
    required int workspaceId,
    required int tagId,
    int? parentTagId,
    int? groupId,
  }) async {
    final schema = await bridge.ensureTagObjectType(workspaceId);
    return database.transaction(() async {
      await bridge.syncLegacyTags(workspaceId);
      final context = await _loadContext(
        workspaceId: workspaceId,
        schema: schema,
      );
      final tagObjectId = context.tagObjectId(tagId);
      final parentObjectId = parentTagId == null
          ? null
          : context.tagObjectId(parentTagId);
      final subtree = _legacySubtree(context, tagObjectId);

      final previousParentObjectId =
          context.snapshot.parentByTagObjectId[tagObjectId];
      final previousParentTagId = previousParentObjectId == null
          ? null
          : context.legacyTagId(previousParentObjectId);
      final previousGroupIds = <int, int?>{};
      for (final entry in subtree) {
        previousGroupIds[entry.legacyTagId] = await _groupLegacyId(
          workspaceId: workspaceId,
          schema: schema,
          context: context,
          tagObjectId: entry.objectId,
        );
      }

      var destinationGroupId = groupId;
      if (parentObjectId != null) {
        final parentGroupId = await _groupLegacyId(
          workspaceId: workspaceId,
          schema: schema,
          context: context,
          tagObjectId: parentObjectId,
        );
        destinationGroupId = parentGroupId ?? groupId;
      }
      final destinationGroupObjectId = destinationGroupId == null
          ? null
          : context.groupObjectId(destinationGroupId);

      await bridge.hierarchyIntegrity.setParent(
        workspaceId: workspaceId,
        tagObjectId: tagObjectId,
        parentProperty: schema.parentProperty,
        parentTagObjectId: parentObjectId,
      );
      for (final entry in subtree) {
        await bridge.hierarchyIntegrity.setGroup(
          workspaceId: workspaceId,
          tagObjectId: entry.objectId,
          groupProperty: schema.groupProperty,
          tagGroupObjectId: destinationGroupObjectId,
        );
      }

      await _writeLegacyParent(tagId: tagId, parentTagId: parentTagId);
      for (final entry in subtree) {
        await _writeLegacyGroup(
          tagId: entry.legacyTagId,
          groupId: destinationGroupId,
        );
      }
      await _writeCheckpoint(
        objectId: tagObjectId,
        property: schema.legacyParentTagIdProperty,
        value: parentTagId,
      );
      for (final entry in subtree) {
        await _writeCheckpoint(
          objectId: entry.objectId,
          property: schema.groupIdProperty,
          value: destinationGroupId,
        );
      }

      await _verifyAppliedState(
        workspaceId: workspaceId,
        schema: schema,
        context: context,
        tagId: tagId,
        tagObjectId: tagObjectId,
        parentObjectId: parentObjectId,
        subtree: subtree,
        groupObjectId: destinationGroupObjectId,
      );

      return TagCompatibilityMoveSnapshot(
        tagId: tagId,
        previousParentTagId: previousParentTagId,
        previousGroupIds: Map<int, int?>.unmodifiable(previousGroupIds),
        appliedParentTagId: parentTagId,
        appliedGroupId: destinationGroupId,
      );
    });
  }

  Future<void> restoreMove({
    required int workspaceId,
    required TagCompatibilityMoveSnapshot snapshot,
  }) async {
    final schema = await bridge.ensureTagObjectType(workspaceId);
    await database.transaction(() async {
      await bridge.syncLegacyTags(workspaceId);
      final context = await _loadContext(
        workspaceId: workspaceId,
        schema: schema,
      );
      final tagObjectId = context.tagObjectId(snapshot.tagId);
      final currentSubtree = _legacySubtree(context, tagObjectId);
      final currentLegacyIds = currentSubtree
          .map((entry) => entry.legacyTagId)
          .toSet();
      if (currentLegacyIds.length != snapshot.previousGroupIds.length ||
          !currentLegacyIds.containsAll(snapshot.previousGroupIds.keys)) {
        throw StateError(
          'Tag hierarchy changed after the move; refusing stale restore.',
        );
      }

      await _requireAppliedState(
        workspaceId: workspaceId,
        schema: schema,
        context: context,
        snapshot: snapshot,
        tagObjectId: tagObjectId,
        subtree: currentSubtree,
      );

      final previousParentObjectId = snapshot.previousParentTagId == null
          ? null
          : context.tagObjectId(snapshot.previousParentTagId!);
      final previousGroupObjectIds = <int, int?>{};
      for (final entry in snapshot.previousGroupIds.entries) {
        previousGroupObjectIds[entry.key] = entry.value == null
            ? null
            : context.groupObjectId(entry.value!);
      }

      await bridge.hierarchyIntegrity.setParent(
        workspaceId: workspaceId,
        tagObjectId: tagObjectId,
        parentProperty: schema.parentProperty,
        parentTagObjectId: previousParentObjectId,
      );
      for (final entry in currentSubtree) {
        await bridge.hierarchyIntegrity.setGroup(
          workspaceId: workspaceId,
          tagObjectId: entry.objectId,
          groupProperty: schema.groupProperty,
          tagGroupObjectId: previousGroupObjectIds[entry.legacyTagId],
        );
      }

      await _writeLegacyParent(
        tagId: snapshot.tagId,
        parentTagId: snapshot.previousParentTagId,
      );
      for (final entry in currentSubtree) {
        final previousGroupId = snapshot.previousGroupIds[entry.legacyTagId];
        await _writeLegacyGroup(
          tagId: entry.legacyTagId,
          groupId: previousGroupId,
        );
        await _writeCheckpoint(
          objectId: entry.objectId,
          property: schema.groupIdProperty,
          value: previousGroupId,
        );
      }
      await _writeCheckpoint(
        objectId: tagObjectId,
        property: schema.legacyParentTagIdProperty,
        value: snapshot.previousParentTagId,
      );

      final restoredContext = await _loadContext(
        workspaceId: workspaceId,
        schema: schema,
      );
      final restoredSubtree = _legacySubtree(restoredContext, tagObjectId);
      await _verifyRestoredState(
        workspaceId: workspaceId,
        schema: schema,
        context: restoredContext,
        snapshot: snapshot,
        tagObjectId: tagObjectId,
        subtree: restoredSubtree,
      );
    });
  }

  Future<_CompatibilityContext> _loadContext({
    required int workspaceId,
    required TagObjectSchema schema,
  }) async {
    final snapshot = await bridge.hierarchyIntegrity.loadSnapshot(
      workspaceId: workspaceId,
      parentProperty: schema.parentProperty,
    );
    final tagObjectIdByLegacyId = <int, int>{};
    final legacyTagIdByObjectId = <int, int>{};
    final legacyTags = await database.select(database.tags).get();
    final legacyTagById = {for (final tag in legacyTags) tag.id: tag};
    for (final tag in legacyTags) {
      final objectId = await bridge.objectIdForLegacyTag(workspaceId, tag.id);
      if (objectId == null ||
          !snapshot.parentByTagObjectId.containsKey(objectId)) {
        throw StateError(
          'Legacy Tag ${tag.id} has no canonical Tag Object mapping.',
        );
      }
      final previous = legacyTagIdByObjectId[objectId];
      if (previous != null && previous != tag.id) {
        throw StateError('Canonical Tag Object mapping is ambiguous.');
      }
      tagObjectIdByLegacyId[tag.id] = objectId;
      legacyTagIdByObjectId[objectId] = tag.id;
    }

    final groupObjectIdByLegacyId = <int, int>{};
    final legacyGroupIdByObjectId = <int, int>{};
    final groupObjects = await objectStore.listObjects(
      schema.tagGroupObjectType.id,
    );
    for (final object in groupObjects) {
      if (!object.values.containsKey(schema.legacyTagGroupIdProperty.id)) {
        continue;
      }
      final legacyId = _positiveInt(
        object.values[schema.legacyTagGroupIdProperty.id],
      );
      if (legacyId == null) {
        throw StateError(
          'Canonical TagGroup Object has a malformed legacy identity.',
        );
      }
      final previous = groupObjectIdByLegacyId[legacyId];
      if (previous != null && previous != object.id) {
        throw StateError(
          'Multiple canonical TagGroup Objects claim legacy TagGroup $legacyId.',
        );
      }
      groupObjectIdByLegacyId[legacyId] = object.id;
      legacyGroupIdByObjectId[object.id] = legacyId;
    }

    final legacyGroups = await database.select(database.tagGroups).get();
    final legacyGroupIds = legacyGroups.map((group) => group.id).toSet();
    for (final group in legacyGroups) {
      if (!groupObjectIdByLegacyId.containsKey(group.id)) {
        throw StateError(
          'Legacy TagGroup ${group.id} has no canonical TagGroup Object mapping.',
        );
      }
    }

    return _CompatibilityContext(
      snapshot: snapshot,
      tagObjectIdByLegacyId: tagObjectIdByLegacyId,
      legacyTagIdByObjectId: legacyTagIdByObjectId,
      groupObjectIdByLegacyId: groupObjectIdByLegacyId,
      legacyGroupIdByObjectId: legacyGroupIdByObjectId,
      legacyTagById: legacyTagById,
      legacyGroupIds: legacyGroupIds,
    );
  }

  List<_LegacyTagTarget> _legacySubtree(
    _CompatibilityContext context,
    int rootObjectId,
  ) {
    final result = <_LegacyTagTarget>[];
    for (final objectId in context.snapshot.parentByTagObjectId.keys) {
      if (objectId != rootObjectId &&
          !context.snapshot.isStrictDescendant(objectId, rootObjectId)) {
        continue;
      }
      final legacyTagId = context.legacyTagIdByObjectId[objectId];
      if (legacyTagId == null) {
        throw StateError(
          'Canonical-only Tag exists inside a legacy Tag subtree; compatibility move cannot project it losslessly.',
        );
      }
      result.add(
        _LegacyTagTarget(objectId: objectId, legacyTagId: legacyTagId),
      );
    }
    result.sort((left, right) => left.legacyTagId.compareTo(right.legacyTagId));
    return result;
  }

  Future<int?> _groupLegacyId({
    required int workspaceId,
    required TagObjectSchema schema,
    required _CompatibilityContext context,
    required int tagObjectId,
  }) async {
    final selection = await bridge.hierarchyIntegrity.relationTargets
        .selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: tagObjectId,
          property: schema.groupProperty,
        );
    if (selection.selectedObjectIds.isEmpty) return null;
    if (selection.selectedObjectIds.length != 1) {
      throw StateError('Canonical Tag Group Relation is not single-valued.');
    }
    final groupObjectId = selection.selectedObjectIds.single;
    final legacyGroupId = context.legacyGroupIdByObjectId[groupObjectId];
    if (legacyGroupId == null ||
        !context.legacyGroupIds.contains(legacyGroupId)) {
      throw StateError(
        'Canonical TagGroup cannot be represented by retained legacy compatibility state.',
      );
    }
    return legacyGroupId;
  }

  Future<void> _requireAppliedState({
    required int workspaceId,
    required TagObjectSchema schema,
    required _CompatibilityContext context,
    required TagCompatibilityMoveSnapshot snapshot,
    required int tagObjectId,
    required List<_LegacyTagTarget> subtree,
  }) async {
    final currentParentObjectId =
        context.snapshot.parentByTagObjectId[tagObjectId];
    final currentParentTagId = currentParentObjectId == null
        ? null
        : context.legacyTagId(currentParentObjectId);
    if (currentParentTagId != snapshot.appliedParentTagId ||
        context.legacyTag(snapshot.tagId).parentTagId !=
            snapshot.appliedParentTagId) {
      throw StateError(
        'Tag Parent changed after the move; refusing stale restore.',
      );
    }

    for (final entry in subtree) {
      final canonicalGroupId = await _groupLegacyId(
        workspaceId: workspaceId,
        schema: schema,
        context: context,
        tagObjectId: entry.objectId,
      );
      final legacyGroupId = context.legacyTag(entry.legacyTagId).groupId;
      if (canonicalGroupId != snapshot.appliedGroupId ||
          legacyGroupId != snapshot.appliedGroupId) {
        throw StateError(
          'Tag Group changed after the move; refusing stale restore.',
        );
      }
    }
  }

  Future<void> _verifyAppliedState({
    required int workspaceId,
    required TagObjectSchema schema,
    required _CompatibilityContext context,
    required int tagId,
    required int tagObjectId,
    required int? parentObjectId,
    required List<_LegacyTagTarget> subtree,
    required int? groupObjectId,
  }) async {
    await _verifyParentState(
      workspaceId: workspaceId,
      schema: schema,
      context: context,
      tagId: tagId,
      tagObjectId: tagObjectId,
      parentObjectId: parentObjectId,
    );
    final expectedGroupId = groupObjectId == null
        ? null
        : context.legacyGroupId(groupObjectId);
    for (final entry in subtree) {
      await _verifyGroupState(
        workspaceId: workspaceId,
        schema: schema,
        context: context,
        target: entry,
        expectedGroupId: expectedGroupId,
      );
    }
  }

  Future<void> _verifyRestoredState({
    required int workspaceId,
    required TagObjectSchema schema,
    required _CompatibilityContext context,
    required TagCompatibilityMoveSnapshot snapshot,
    required int tagObjectId,
    required List<_LegacyTagTarget> subtree,
  }) async {
    final parentObjectId = snapshot.previousParentTagId == null
        ? null
        : context.tagObjectId(snapshot.previousParentTagId!);
    await _verifyParentState(
      workspaceId: workspaceId,
      schema: schema,
      context: context,
      tagId: snapshot.tagId,
      tagObjectId: tagObjectId,
      parentObjectId: parentObjectId,
    );
    for (final entry in subtree) {
      await _verifyGroupState(
        workspaceId: workspaceId,
        schema: schema,
        context: context,
        target: entry,
        expectedGroupId: snapshot.previousGroupIds[entry.legacyTagId],
      );
    }
  }

  Future<void> _verifyParentState({
    required int workspaceId,
    required TagObjectSchema schema,
    required _CompatibilityContext context,
    required int tagId,
    required int tagObjectId,
    required int? parentObjectId,
  }) async {
    final parentSelection = await bridge.hierarchyIntegrity.relationTargets
        .selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: tagObjectId,
          property: schema.parentProperty,
        );
    final expectedParentIds = parentObjectId == null
        ? const <int>[]
        : <int>[parentObjectId];
    if (!_sameIds(parentSelection.selectedObjectIds, expectedParentIds)) {
      throw StateError('Canonical Tag Parent verification failed.');
    }
    final legacy = await (database.select(
      database.tags,
    )..where((tag) => tag.id.equals(tagId))).getSingleOrNull();
    if (legacy == null) {
      throw StateError('Legacy Tag disappeared during compatibility move.');
    }
    final expectedParentTagId = parentObjectId == null
        ? null
        : context.legacyTagId(parentObjectId);
    if (legacy.parentTagId != expectedParentTagId) {
      throw StateError('Legacy Tag Parent projection verification failed.');
    }
  }

  Future<void> _verifyGroupState({
    required int workspaceId,
    required TagObjectSchema schema,
    required _CompatibilityContext context,
    required _LegacyTagTarget target,
    required int? expectedGroupId,
  }) async {
    final groupSelection = await bridge.hierarchyIntegrity.relationTargets
        .selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: target.objectId,
          property: schema.groupProperty,
        );
    final expectedGroupObjectId = expectedGroupId == null
        ? null
        : context.groupObjectId(expectedGroupId);
    final expectedGroupIds = expectedGroupObjectId == null
        ? const <int>[]
        : <int>[expectedGroupObjectId];
    if (!_sameIds(groupSelection.selectedObjectIds, expectedGroupIds)) {
      throw StateError('Canonical Tag Group verification failed.');
    }
    final legacy = await (database.select(
      database.tags,
    )..where((tag) => tag.id.equals(target.legacyTagId))).getSingleOrNull();
    if (legacy == null) {
      throw StateError('Legacy Tag disappeared during compatibility move.');
    }
    if (legacy.groupId != expectedGroupId) {
      throw StateError('Legacy Tag Group projection verification failed.');
    }
  }

  Future<void> _writeLegacyParent({
    required int tagId,
    required int? parentTagId,
  }) async {
    final changed =
        await (database.update(database.tags)
              ..where((tag) => tag.id.equals(tagId)))
            .write(TagsCompanion(parentTagId: Value(parentTagId)));
    if (changed != 1) {
      throw StateError('Legacy Tag Parent projection target is missing.');
    }
  }

  Future<void> _writeLegacyGroup({
    required int tagId,
    required int? groupId,
  }) async {
    final changed =
        await (database.update(database.tags)
              ..where((tag) => tag.id.equals(tagId)))
            .write(TagsCompanion(groupId: Value(groupId)));
    if (changed != 1) {
      throw StateError('Legacy Tag Group projection target is missing.');
    }
  }

  Future<void> _writeCheckpoint({
    required int objectId,
    required ObjectPropertyDefinition property,
    required int? value,
  }) => objectStore.setPropertyValue(
    objectId: objectId,
    property: property,
    value: value,
  );

  int? _positiveInt(dynamic raw) {
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw > 0 && raw == raw.toInt()) return raw.toInt();
    final parsed = int.tryParse('$raw');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  bool _sameIds(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class _CompatibilityContext {
  const _CompatibilityContext({
    required this.snapshot,
    required this.tagObjectIdByLegacyId,
    required this.legacyTagIdByObjectId,
    required this.groupObjectIdByLegacyId,
    required this.legacyGroupIdByObjectId,
    required this.legacyTagById,
    required this.legacyGroupIds,
  });

  final TagHierarchySnapshot snapshot;
  final Map<int, int> tagObjectIdByLegacyId;
  final Map<int, int> legacyTagIdByObjectId;
  final Map<int, int> groupObjectIdByLegacyId;
  final Map<int, int> legacyGroupIdByObjectId;
  final Map<int, Tag> legacyTagById;
  final Set<int> legacyGroupIds;

  int tagObjectId(int legacyTagId) {
    final objectId = tagObjectIdByLegacyId[legacyTagId];
    if (objectId == null) {
      throw ArgumentError.value(
        legacyTagId,
        'tagId',
        'Legacy Tag has no canonical Tag Object mapping.',
      );
    }
    return objectId;
  }

  int legacyTagId(int objectId) {
    final legacyTagId = legacyTagIdByObjectId[objectId];
    if (legacyTagId == null) {
      throw StateError(
        'Canonical Tag cannot be represented by retained legacy compatibility state.',
      );
    }
    return legacyTagId;
  }

  int groupObjectId(int legacyGroupId) {
    if (!legacyGroupIds.contains(legacyGroupId)) {
      throw ArgumentError.value(
        legacyGroupId,
        'groupId',
        'Legacy TagGroup does not exist.',
      );
    }
    final objectId = groupObjectIdByLegacyId[legacyGroupId];
    if (objectId == null) {
      throw StateError(
        'Legacy TagGroup has no canonical TagGroup Object mapping.',
      );
    }
    return objectId;
  }

  int legacyGroupId(int objectId) {
    final legacyGroupId = legacyGroupIdByObjectId[objectId];
    if (legacyGroupId == null || !legacyGroupIds.contains(legacyGroupId)) {
      throw StateError(
        'Canonical TagGroup cannot be represented by retained legacy compatibility state.',
      );
    }
    return legacyGroupId;
  }

  Tag legacyTag(int legacyTagId) {
    final tag = legacyTagById[legacyTagId];
    if (tag == null) {
      throw StateError('Legacy Tag $legacyTagId is missing.');
    }
    return tag;
  }
}

class _LegacyTagTarget {
  const _LegacyTagTarget({required this.objectId, required this.legacyTagId});

  final int objectId;
  final int legacyTagId;
}
