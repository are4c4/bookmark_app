import '../domain/object_history_contract.dart';
import '../domain/object_history_relation.dart';
import '../domain/object_model.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_integrity_service.dart';
import 'relation_mutation_service.dart';
import 'relation_stored_value_inspector.dart';

/// B-owned capture/restore boundary for durable Relation history.
///
/// Historical evidence is immutable and preserves retired target ids exactly.
/// Restore planning always revalidates the current canonical Relation schema and
/// graph. Any A-owned redirect resolution is supplied explicitly as a mapping
/// from historical target id to the current canonical target id; the historical
/// snapshot itself is never rewritten.
class ObjectHistoryRelationService {
  const ObjectHistoryRelationService({
    required this.objectStore,
    required this.bidirectionalStore,
    required this.mutationService,
    required this.genericStore,
  });

  final ObjectStore objectStore;
  final BidirectionalRelationStore bidirectionalStore;
  final RelationMutationService mutationService;
  final GenericDatabaseStore genericStore;

  Future<ObjectHistoryRelationSnapshot> capture({
    required int workspaceId,
    required int sourceObjectId,
    required int propertyId,
  }) async {
    _validatePositiveId(workspaceId, 'workspaceId');
    _validatePositiveId(sourceObjectId, 'sourceObjectId');
    _validatePositiveId(propertyId, 'propertyId');

    final report = await _audit(workspaceId);
    if (!report.isHealthy) {
      throw StateError(
        'Cannot capture Relation history from an unhealthy canonical graph: '
        '${report.issues.first.message}',
      );
    }

    final objectTypes = await objectStore.listObjectTypes(workspaceId);
    ObjectPropertyDefinition? property;
    AppObjectType? sourceType;
    for (final candidateType in objectTypes) {
      for (final candidateProperty in candidateType.properties) {
        if (candidateProperty.id == propertyId) {
          sourceType = candidateType;
          property = candidateProperty;
          break;
        }
      }
      if (property != null) break;
    }
    if (sourceType == null || property == null || !property.isRelation) {
      throw ArgumentError.value(
        propertyId,
        'propertyId',
        'Relation Property must exist in the supplied workspace.',
      );
    }

    final source = await _objectById(sourceType.id, sourceObjectId);
    if (source == null) {
      throw ArgumentError.value(
        sourceObjectId,
        'sourceObjectId',
        'Source Object does not belong to the Relation source ObjectType.',
      );
    }
    final targetTypeId = property.targetObjectTypeId;
    if (targetTypeId == null) {
      throw StateError('Canonical Relation Property has no target ObjectType.');
    }

    final inspection = inspectRelationStoredValue(source.values[property.id]);
    if (inspection.isMalformed) {
      throw StateError(
        'Cannot capture malformed persisted Relation value for Object '
        '$sourceObjectId / Property $propertyId.',
      );
    }

    final pair = await _pairForValidatedProperty(property);
    return ObjectHistoryRelationSnapshot(
      sourceObjectId: sourceObjectId,
      sourceObjectTypeId: sourceType.id,
      propertyId: property.id,
      targetObjectTypeId: targetTypeId,
      allowsMultipleRelations: property.allowsMultipleRelations,
      targetObjectIds: inspection.value.objectIds,
      inversePropertyId: pair?.inverseProperty.id,
      pairRole: pair == null ? null : _pairRole(property),
      inverseAllowsMultipleRelations:
          pair?.inverseProperty.allowsMultipleRelations,
    );
  }

  Future<ObjectHistoryRelationRestorePlan> previewRestore({
    required int workspaceId,
    required ObjectHistoryRelationSnapshot historical,
    Map<int, int> targetResolutions = const <int, int>{},
  }) async {
    _validatePositiveId(workspaceId, 'workspaceId');
    _validateResolutionMap(historical, targetResolutions);

    final blockers = <ObjectHistoryRelationBlocker>[];
    final blockerKeys = <String>{};
    void block(String key, String reason) {
      if (!blockerKeys.add(key)) return;
      blockers.add(ObjectHistoryRelationBlocker(key: key, reason: reason));
    }

    final report = await _audit(workspaceId);
    if (!report.isHealthy) {
      _addIntegrityBlockers(report, block);
      return _blockedPlan(
        workspaceId: workspaceId,
        historical: historical,
        targetResolutions: targetResolutions,
        blockers: blockers,
      );
    }

    final sourceType = await objectStore.getObjectType(
      historical.sourceObjectTypeId,
    );
    if (sourceType == null || sourceType.workspaceId != workspaceId) {
      block(
        'source-type:${historical.sourceObjectTypeId}:missing',
        'Historical Relation source ObjectType no longer exists in the workspace.',
      );
      return _blockedPlan(
        workspaceId: workspaceId,
        historical: historical,
        targetResolutions: targetResolutions,
        blockers: blockers,
      );
    }

    final source = await _objectById(sourceType.id, historical.sourceObjectId);
    if (source == null) {
      block(
        'source:${historical.sourceObjectId}:missing',
        'Historical Relation source Object no longer exists in its ObjectType.',
      );
      return _blockedPlan(
        workspaceId: workspaceId,
        historical: historical,
        targetResolutions: targetResolutions,
        blockers: blockers,
      );
    }

    ObjectPropertyDefinition? property;
    for (final candidate in sourceType.properties) {
      if (candidate.id == historical.propertyId) {
        property = candidate;
        break;
      }
    }
    if (property == null || !property.isRelation) {
      block(
        'property:${historical.propertyId}:missing',
        'Historical Relation Property no longer exists as a current Relation Property.',
      );
      return _blockedPlan(
        workspaceId: workspaceId,
        historical: historical,
        targetResolutions: targetResolutions,
        blockers: blockers,
      );
    }

    final inspection = inspectRelationStoredValue(source.values[property.id]);
    if (inspection.isMalformed) {
      block(
        'property:${property.id}:malformed-current-value',
        'Current persisted Relation value is malformed.',
      );
    }
    final beforeTargetObjectIds = inspection.value.objectIds;

    final currentTargetTypeId = property.targetObjectTypeId;
    if (currentTargetTypeId == null) {
      block(
        'property:${property.id}:missing-target-type',
        'Current Relation Property has no target ObjectType.',
      );
      return ObjectHistoryRelationRestorePlan(
        workspaceId: workspaceId,
        historical: historical,
        beforeTargetObjectIds: beforeTargetObjectIds,
        targetResolutions: _defaultResolutions(historical, targetResolutions),
        blockers: blockers,
        changedObjectIds: const <int>[],
      );
    }
    if (currentTargetTypeId != historical.targetObjectTypeId) {
      block(
        'property:${property.id}:target-type-changed',
        'Current Relation target ObjectType differs from the historical contract.',
      );
    }
    if (property.allowsMultipleRelations !=
        historical.allowsMultipleRelations) {
      block(
        'property:${property.id}:cardinality-changed',
        'Current Relation cardinality differs from the historical contract.',
      );
    }

    BidirectionalRelationPair? pair;
    final hasPairMetadata = bidirectionalStore.hasManagedPairMetadata(property);
    if (hasPairMetadata) {
      pair = await bidirectionalStore.pairFor(property);
      if (pair == null) {
        block(
          'property:${property.id}:invalid-pair',
          'Current Relation Property has inconsistent bidirectional metadata.',
        );
      }
    }
    final currentRole = pair == null ? null : _pairRole(property);
    if (historical.isBidirectional != (pair != null)) {
      block(
        'property:${property.id}:pair-semantics-changed',
        'Current bidirectional Relation semantics differ from the historical contract.',
      );
    } else if (pair != null &&
        (historical.inversePropertyId != pair.inverseProperty.id ||
            historical.pairRole != currentRole ||
            historical.inverseAllowsMultipleRelations !=
                pair.inverseProperty.allowsMultipleRelations)) {
      block(
        'property:${property.id}:pair-contract-changed',
        'Current inverse Relation identity, role, or cardinality differs from history.',
      );
    }

    final targetType = await objectStore.getObjectType(currentTargetTypeId);
    if (targetType == null || targetType.workspaceId != workspaceId) {
      block(
        'target-type:$currentTargetTypeId:missing',
        'Current Relation target ObjectType does not exist in the workspace.',
      );
      return ObjectHistoryRelationRestorePlan(
        workspaceId: workspaceId,
        historical: historical,
        beforeTargetObjectIds: beforeTargetObjectIds,
        targetResolutions: _defaultResolutions(historical, targetResolutions),
        blockers: blockers,
        changedObjectIds: const <int>[],
      );
    }

    final targetObjects = await objectStore.listObjects(currentTargetTypeId);
    final targetObjectsById = <int, AppObject>{
      for (final target in targetObjects) target.id: target,
    };
    final resolutions = <ObjectHistoryRelationTargetResolution>[];
    for (final historicalTargetId in historical.targetObjectIds) {
      final historicalTargetExists = targetObjectsById.containsKey(
        historicalTargetId,
      );
      final explicitResolution = targetResolutions[historicalTargetId];
      if (historicalTargetExists) {
        if (explicitResolution != null &&
            explicitResolution != historicalTargetId) {
          block(
            'target:$historicalTargetId:unexpected-resolution',
            'A live historical Relation target cannot be silently redirected during restore.',
          );
        }
        resolutions.add(
          ObjectHistoryRelationTargetResolution(
            historicalTargetObjectId: historicalTargetId,
            currentTargetObjectId: historicalTargetId,
          ),
        );
        continue;
      }

      if (explicitResolution == null) {
        block(
          'target:$historicalTargetId:resolution-required',
          'Historical Relation target $historicalTargetId is retired or missing; explicit current identity resolution is required.',
        );
        resolutions.add(
          ObjectHistoryRelationTargetResolution(
            historicalTargetObjectId: historicalTargetId,
            currentTargetObjectId: historicalTargetId,
          ),
        );
        continue;
      }
      if (!targetObjectsById.containsKey(explicitResolution)) {
        block(
          'target:$historicalTargetId:invalid-resolution',
          'Resolved Relation target $explicitResolution does not exist in the current target ObjectType.',
        );
      }
      resolutions.add(
        ObjectHistoryRelationTargetResolution(
          historicalTargetObjectId: historicalTargetId,
          currentTargetObjectId: explicitResolution,
        ),
      );
    }

    final afterTargetObjectIds = resolutions
        .map((resolution) => resolution.currentTargetObjectId)
        .toList(growable: false);
    if (afterTargetObjectIds.toSet().length != afterTargetObjectIds.length) {
      block(
        'property:${property.id}:duplicate-resolution',
        'Historical Relation targets resolve to duplicate current Objects; restore requires an explicit conflict decision.',
      );
    }
    if (!property.allowsMultipleRelations && afterTargetObjectIds.length > 1) {
      block(
        'property:${property.id}:cardinality-conflict',
        'Historical Relation state violates the current single-target cardinality.',
      );
    }

    if (pair != null) {
      final beforeIds = beforeTargetObjectIds.toSet();
      final afterIds = afterTargetObjectIds.toSet();
      final addedIds = afterIds.difference(beforeIds);
      if (!pair.inverseProperty.allowsMultipleRelations) {
        for (final targetId in addedIds) {
          final target = targetObjectsById[targetId];
          if (target == null) continue;
          final inverseInspection = inspectRelationStoredValue(
            target.values[pair.inverseProperty.id],
          );
          if (inverseInspection.isMalformed) {
            block(
              'target:$targetId:malformed-inverse',
              'Current inverse Relation value is malformed.',
            );
            continue;
          }
          final inverseIds = inverseInspection.value.objectIds;
          if (inverseIds.isNotEmpty &&
              !inverseIds.contains(historical.sourceObjectId)) {
            block(
              'target:$targetId:inverse-cardinality-conflict',
              'Restoring this Relation would overwrite another Object in a single inverse Relation.',
            );
          }
        }
      }
    }

    final changedObjectIds = <int>[];
    if (blockers.isEmpty &&
        !_sameIntList(beforeTargetObjectIds, afterTargetObjectIds)) {
      final changed = <int>{historical.sourceObjectId};
      if (pair != null) {
        changed.addAll(beforeTargetObjectIds);
        changed.addAll(afterTargetObjectIds);
      }
      changedObjectIds.addAll(changed..removeWhere((id) => id <= 0));
      changedObjectIds.sort();
    }

    return ObjectHistoryRelationRestorePlan(
      workspaceId: workspaceId,
      historical: historical,
      beforeTargetObjectIds: beforeTargetObjectIds,
      targetResolutions: resolutions,
      blockers: blockers,
      changedObjectIds: changedObjectIds,
    );
  }

  Future<ObjectHistoryRelationRestoreImpact> applyRestore(
    ObjectHistoryRelationRestorePlan plan,
  ) async {
    if (!plan.isExecutable) {
      throw StateError(
        'Blocked Relation history restore plans cannot be applied.',
      );
    }

    return genericStore.database.transaction(() async {
      final fresh = await previewRestore(
        workspaceId: plan.workspaceId,
        historical: plan.historical,
        targetResolutions: plan.explicitRedirectResolutions,
      );
      if (!fresh.isExecutable || !_samePlan(plan, fresh)) {
        throw StateError(
          'Relation history restore plan is stale; preview again before applying.',
        );
      }

      if (fresh.hasChanges) {
        final sourceType = await objectStore.getObjectType(
          fresh.historical.sourceObjectTypeId,
        );
        final property = sourceType?.properties
            .where((candidate) => candidate.id == fresh.historical.propertyId)
            .firstOrNull;
        if (property == null || !property.isRelation) {
          throw StateError(
            'Current Relation Property disappeared during history restore.',
          );
        }
        await mutationService.setRelation(
          objectId: fresh.historical.sourceObjectId,
          property: property,
          targetObjectIds: fresh.afterTargetObjectIds,
        );
      }

      final after = await _audit(plan.workspaceId);
      if (!after.isHealthy) {
        throw StateError(
          'Relation history restore produced an integrity violation.',
        );
      }
      return ObjectHistoryRelationRestoreImpact(
        changedObjectIds: fresh.changedObjectIds,
      );
    });
  }

  Future<RelationIntegrityReport> _audit(int workspaceId) =>
      RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
      ).auditWorkspace(workspaceId);

  Future<AppObject?> _objectById(int objectTypeId, int objectId) async {
    for (final object in await objectStore.listObjects(objectTypeId)) {
      if (object.id == objectId) return object;
    }
    return null;
  }

  Future<BidirectionalRelationPair?> _pairForValidatedProperty(
    ObjectPropertyDefinition property,
  ) async {
    if (!bidirectionalStore.hasManagedPairMetadata(property)) return null;
    final pair = await bidirectionalStore.pairFor(property);
    if (pair == null) {
      throw StateError(
        'Canonical Relation Property has inconsistent bidirectional metadata.',
      );
    }
    return pair;
  }
}

ObjectHistoryRelationPairRole _pairRole(ObjectPropertyDefinition property) =>
    switch (property.config['pairRole']) {
      'source' => ObjectHistoryRelationPairRole.source,
      'inverse' => ObjectHistoryRelationPairRole.inverse,
      _ => throw StateError('Canonical Relation pair role is invalid.'),
    };

void _validatePositiveId(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, '$name must be positive.');
  }
}

void _validateResolutionMap(
  ObjectHistoryRelationSnapshot historical,
  Map<int, int> targetResolutions,
) {
  final historicalIds = historical.targetObjectIds.toSet();
  for (final entry in targetResolutions.entries) {
    if (!historicalIds.contains(entry.key)) {
      throw ArgumentError.value(
        entry.key,
        'targetResolutions',
        'Only historical Relation targets may have explicit resolutions.',
      );
    }
    if (entry.key <= 0 || entry.value <= 0) {
      throw ArgumentError.value(
        targetResolutions,
        'targetResolutions',
        'Relation target resolutions must contain positive Object ids.',
      );
    }
  }
}

ObjectHistoryRelationRestorePlan _blockedPlan({
  required int workspaceId,
  required ObjectHistoryRelationSnapshot historical,
  required Map<int, int> targetResolutions,
  required List<ObjectHistoryRelationBlocker> blockers,
}) => ObjectHistoryRelationRestorePlan(
  workspaceId: workspaceId,
  historical: historical,
  beforeTargetObjectIds: const <int>[],
  targetResolutions: _defaultResolutions(historical, targetResolutions),
  blockers: blockers,
  changedObjectIds: const <int>[],
);

List<ObjectHistoryRelationTargetResolution> _defaultResolutions(
  ObjectHistoryRelationSnapshot historical,
  Map<int, int> targetResolutions,
) => <ObjectHistoryRelationTargetResolution>[
  for (final historicalTargetId in historical.targetObjectIds)
    ObjectHistoryRelationTargetResolution(
      historicalTargetObjectId: historicalTargetId,
      currentTargetObjectId:
          targetResolutions[historicalTargetId] ?? historicalTargetId,
    ),
];

void _addIntegrityBlockers(
  RelationIntegrityReport report,
  void Function(String key, String reason) block,
) {
  for (var index = 0; index < report.issues.length; index += 1) {
    final issue = report.issues[index];
    block(
      'relation-integrity:${issue.kind.name}:${issue.sourceObjectId ?? 0}:'
      '${issue.propertyId ?? 0}:${issue.targetObjectId ?? 0}:$index',
      issue.message,
    );
  }
}

bool _samePlan(
  ObjectHistoryRelationRestorePlan expected,
  ObjectHistoryRelationRestorePlan actual,
) {
  if (expected.workspaceId != actual.workspaceId ||
      !_sameSnapshot(expected.historical, actual.historical) ||
      !_sameIntList(
        expected.beforeTargetObjectIds,
        actual.beforeTargetObjectIds,
      ) ||
      !_sameIntList(
        expected.afterTargetObjectIds,
        actual.afterTargetObjectIds,
      ) ||
      !_sameIntList(expected.changedObjectIds, actual.changedObjectIds)) {
    return false;
  }
  return true;
}

bool _sameSnapshot(
  ObjectHistoryRelationSnapshot left,
  ObjectHistoryRelationSnapshot right,
) =>
    left.sourceObjectId == right.sourceObjectId &&
    left.sourceObjectTypeId == right.sourceObjectTypeId &&
    left.propertyId == right.propertyId &&
    left.targetObjectTypeId == right.targetObjectTypeId &&
    left.allowsMultipleRelations == right.allowsMultipleRelations &&
    left.ordering == right.ordering &&
    left.inversePropertyId == right.inversePropertyId &&
    left.pairRole == right.pairRole &&
    left.inverseAllowsMultipleRelations ==
        right.inverseAllowsMultipleRelations &&
    _sameIntList(left.targetObjectIds, right.targetObjectIds);

bool _sameIntList(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
