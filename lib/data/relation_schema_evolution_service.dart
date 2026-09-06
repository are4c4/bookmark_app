import '../domain/object_model.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_integrity_service.dart';
import 'relation_mutation_service.dart';

class RelationSchemaChangeImpact {
  const RelationSchemaChangeImpact({
    required this.property,
    required this.currentTargetObjectTypeId,
    required this.nextTargetObjectTypeId,
    required this.currentMultiple,
    required this.nextMultiple,
    required this.affectedSourceObjectCount,
    required this.multiToSingleConflicts,
  });

  final ObjectPropertyDefinition property;
  final int currentTargetObjectTypeId;
  final int nextTargetObjectTypeId;
  final bool currentMultiple;
  final bool nextMultiple;
  final int affectedSourceObjectCount;
  final Map<int, List<int>> multiToSingleConflicts;

  bool get changesTargetObjectType =>
      currentTargetObjectTypeId != nextTargetObjectTypeId;

  bool get changesCardinality => currentMultiple != nextMultiple;

  bool get hasChanges => changesTargetObjectType || changesCardinality;

  bool get requiresMultiToSingleChoice => multiToSingleConflicts.isNotEmpty;
}

/// Owns the data-integrity side of user-driven Relation schema changes.
///
/// The service is intentionally UI-agnostic. Callers may inspect a proposed
/// change to present an impact summary, then submit explicit per-Object choices
/// for ambiguous multi -> single reductions. Apply always re-validates inside a
/// transaction, so a stale preview cannot silently discard or retarget data.
class RelationSchemaEvolutionService {
  const RelationSchemaEvolutionService({
    required this.objectStore,
    required this.genericStore,
    required this.relationMutations,
  });

  final ObjectStore objectStore;
  final GenericDatabaseStore genericStore;
  final RelationMutationService relationMutations;

  Future<RelationSchemaChangeImpact> inspectChange({
    required ObjectPropertyDefinition property,
    required int targetObjectTypeId,
    required bool multiple,
  }) async {
    await objectStore.ensureRelationIndexSchema();
    return _inspectChange(
      property: property,
      targetObjectTypeId: targetObjectTypeId,
      multiple: multiple,
    );
  }

  Future<ObjectPropertyDefinition> updateRelationSchema({
    required ObjectPropertyDefinition property,
    required int targetObjectTypeId,
    required bool multiple,
    Map<int, int> multiToSingleSelections = const <int, int>{},
  }) async {
    await objectStore.ensureRelationIndexSchema();
    return genericStore.database.transaction(() async {
      final impact = await _inspectChange(
        property: property,
        targetObjectTypeId: targetObjectTypeId,
        multiple: multiple,
      );
      if (!impact.hasChanges) return impact.property;

      for (final entry in impact.multiToSingleConflicts.entries) {
        final selectedTargetId = multiToSingleSelections[entry.key];
        if (selectedTargetId == null || !entry.value.contains(selectedTargetId)) {
          throw StateError(
            'Relation ${impact.property.name} requires an explicit existing target '
            'choice for Object ${entry.key} before changing to single cardinality.',
          );
        }
      }

      for (final entry in impact.multiToSingleConflicts.entries) {
        await relationMutations.setRelation(
          objectId: entry.key,
          property: impact.property,
          targetObjectIds: <int>[multiToSingleSelections[entry.key]!],
        );
      }

      await genericStore.updateProperty(
        GenericPropertyRecord(
          id: impact.property.id,
          databaseId: impact.property.objectTypeId,
          name: impact.property.name,
          type: impact.property.storageType,
          sortOrder: impact.property.sortOrder,
          config: <String, dynamic>{
            ...impact.property.config,
            'targetObjectTypeId': targetObjectTypeId,
            'multiple': multiple,
          },
        ),
      );

      final refreshed = await _canonicalRelationProperty(impact.property);
      await _inspectChange(
        property: refreshed,
        targetObjectTypeId: targetObjectTypeId,
        multiple: multiple,
      );
      return refreshed;
    });
  }

  Future<RelationSchemaChangeImpact> _inspectChange({
    required ObjectPropertyDefinition property,
    required int targetObjectTypeId,
    required bool multiple,
  }) async {
    final storedProperty = await _canonicalRelationProperty(property);
    final sourceType = await objectStore.getObjectType(storedProperty.objectTypeId);
    if (sourceType == null) {
      throw StateError('Relation source ObjectType no longer exists.');
    }
    if (sourceType.kind == ObjectTypeKind.system) {
      throw StateError('System Relation Properties cannot be changed by users.');
    }

    final currentTargetObjectTypeId = storedProperty.targetObjectTypeId;
    if (currentTargetObjectTypeId == null) {
      throw StateError(
        'Relation Property ${storedProperty.name} has no target ObjectType.',
      );
    }
    final currentTargetType = await objectStore.getObjectType(
      currentTargetObjectTypeId,
    );
    if (currentTargetType == null ||
        currentTargetType.workspaceId != sourceType.workspaceId) {
      throw StateError(
        'Relation Property ${storedProperty.name} has an invalid current target ObjectType.',
      );
    }

    final nextTargetType = await objectStore.getObjectType(targetObjectTypeId);
    if (nextTargetType == null ||
        nextTargetType.workspaceId != sourceType.workspaceId) {
      throw ArgumentError.value(
        targetObjectTypeId,
        'targetObjectTypeId',
        'Relation target ObjectType must exist in the same workspace.',
      );
    }

    final hasPairMetadata = storedProperty.config['bidirectional'] == true ||
        storedProperty.config['inversePropertyId'] != null ||
        storedProperty.config['pairRole'] != null;
    final pair = hasPairMetadata
        ? await relationMutations.bidirectionalStore.pairFor(storedProperty)
        : null;
    if (hasPairMetadata && pair == null) {
      throw StateError(
        'Relation Property ${storedProperty.name} has inconsistent bidirectional metadata.',
      );
    }
    if (pair != null && currentTargetObjectTypeId != targetObjectTypeId) {
      throw StateError(
        'Bidirectional Relation target changes require an explicit paired migration.',
      );
    }

    final relevantPropertyIds = <int>{
      storedProperty.id,
      if (pair != null) pair.inverseProperty.id,
    };
    final report = await RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: relationMutations.bidirectionalStore,
    ).auditWorkspace(sourceType.workspaceId);
    final integrityIssues = report.issues
        .where(
          (issue) => issue.propertyId != null &&
              relevantPropertyIds.contains(issue.propertyId),
        )
        .toList(growable: false);
    if (integrityIssues.isNotEmpty) {
      throw StateError(
        'Relation schema migration requires healthy persisted Relation state: '
        '${integrityIssues.first.message}',
      );
    }

    final sourceObjects = await objectStore.listObjects(sourceType.id);
    final nextTargetIds = (await objectStore.listObjects(targetObjectTypeId))
        .map((object) => object.id)
        .toSet();
    final conflicts = <int, List<int>>{};
    var affectedSourceObjectCount = 0;

    for (final source in sourceObjects) {
      final relation = ObjectRelationValue.fromJson(
        source.values[storedProperty.id],
      );
      final ids = relation.objectIds;
      if (ids.isNotEmpty) affectedSourceObjectCount++;

      final invalidForNextTarget = ids
          .where((targetId) => !nextTargetIds.contains(targetId))
          .toList(growable: false);
      if (invalidForNextTarget.isNotEmpty) {
        throw StateError(
          'Relation ${storedProperty.name} cannot target ObjectType '
          '$targetObjectTypeId because Object ${source.id} currently references '
          'targets that do not belong to it: $invalidForNextTarget.',
        );
      }

      if (!multiple && storedProperty.allowsMultipleRelations && ids.length > 1) {
        conflicts[source.id] = List<int>.unmodifiable(ids);
      }
    }

    return RelationSchemaChangeImpact(
      property: storedProperty,
      currentTargetObjectTypeId: currentTargetObjectTypeId,
      nextTargetObjectTypeId: targetObjectTypeId,
      currentMultiple: storedProperty.allowsMultipleRelations,
      nextMultiple: multiple,
      affectedSourceObjectCount: affectedSourceObjectCount,
      multiToSingleConflicts: Map<int, List<int>>.unmodifiable(conflicts),
    );
  }

  Future<ObjectPropertyDefinition> _canonicalRelationProperty(
    ObjectPropertyDefinition property,
  ) async {
    final sourceType = await objectStore.getObjectType(property.objectTypeId);
    if (sourceType == null) {
      throw ArgumentError.value(
        property.objectTypeId,
        'property',
        'Relation source ObjectType does not exist.',
      );
    }
    for (final candidate in sourceType.properties) {
      if (candidate.id != property.id) continue;
      if (!candidate.isRelation) {
        throw ArgumentError.value(
          property.id,
          'property',
          'Property is not a persisted Relation Property.',
        );
      }
      return candidate;
    }
    throw ArgumentError.value(
      property.id,
      'property',
      'Relation Property does not belong to its declared source ObjectType.',
    );
  }
}
