import '../domain/object_merge_contract.dart';
import '../domain/object_model.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_integrity_service.dart';
import 'relation_mutation_service.dart';
import 'relation_stored_value_inspector.dart';

/// One canonical Relation value change required before an Object can retire.
class RelationObjectMergeMutation {
  RelationObjectMergeMutation({
    required this.sourceObjectId,
    required this.propertyId,
    required List<int> beforeTargetObjectIds,
    required List<int> afterTargetObjectIds,
  }) : beforeTargetObjectIds = List<int>.unmodifiable(beforeTargetObjectIds),
       afterTargetObjectIds = List<int>.unmodifiable(afterTargetObjectIds);

  final int sourceObjectId;
  final int propertyId;
  final List<int> beforeTargetObjectIds;
  final List<int> afterTargetObjectIds;
}

/// Read-only B-owned Relation half of an explicit Object merge plan.
///
/// [relationBlockers] can be passed directly to the A-owned
/// `ObjectMergePreview`. An executable plan contains the exact canonical
/// Relation values that must change before the retired Object is deleted.
class RelationObjectMergePlan {
  RelationObjectMergePlan({
    required this.workspaceId,
    required this.objectTypeId,
    required this.survivorObjectId,
    required this.retiredObjectId,
    required List<RelationObjectMergeMutation> mutations,
    required List<ObjectMergeRelationBlocker> relationBlockers,
    required List<int> changedSurvivingSourceObjectIds,
  }) : mutations = List<RelationObjectMergeMutation>.unmodifiable(mutations),
       relationBlockers = List<ObjectMergeRelationBlocker>.unmodifiable(
         relationBlockers,
       ),
       changedSurvivingSourceObjectIds = List<int>.unmodifiable(
         changedSurvivingSourceObjectIds,
       );

  final int workspaceId;
  final int objectTypeId;
  final int survivorObjectId;
  final int retiredObjectId;
  final List<RelationObjectMergeMutation> mutations;
  final List<ObjectMergeRelationBlocker> relationBlockers;
  final List<int> changedSurvivingSourceObjectIds;

  bool get isExecutable => relationBlockers.isEmpty;
}

class RelationObjectMergeImpact {
  RelationObjectMergeImpact({
    required List<int> changedSurvivingSourceObjectIds,
  }) : changedSurvivingSourceObjectIds = List<int>.unmodifiable(
         changedSurvivingSourceObjectIds,
       );

  final List<int> changedSurvivingSourceObjectIds;
}

/// Canonical Relation planning/execution boundary for Object merge.
///
/// Planning is fail-closed. Existing persisted Relation values, normalized
/// edges, targets, cardinality and bidirectional pairs must already pass the
/// read-only workspace integrity audit. Merge planning never repairs drift,
/// because rebuilding an index here would erase evidence that must block an
/// integrity-sensitive identity merge.
///
/// Execution re-plans inside the database transaction, rejects stale plans,
/// clears the retired Object's outgoing Relations first, then applies surviving
/// values only through [RelationMutationService]. This composes with a caller's
/// outer transaction so a later A-owned redirect/delete failure rolls back all
/// Relation rewrites as one unit.
class RelationObjectMergeService {
  const RelationObjectMergeService({
    required this.objectStore,
    required this.mutationService,
    required this.bidirectionalStore,
    required this.genericStore,
  });

  final ObjectStore objectStore;
  final RelationMutationService mutationService;
  final BidirectionalRelationStore bidirectionalStore;
  final GenericDatabaseStore genericStore;

  Future<RelationObjectMergePlan> preview({
    required int workspaceId,
    required int objectTypeId,
    required int survivorObjectId,
    required int retiredObjectId,
  }) async {
    _validateIds(
      survivorObjectId: survivorObjectId,
      retiredObjectId: retiredObjectId,
    );

    final mergeType = await objectStore.getObjectType(objectTypeId);
    if (mergeType == null || mergeType.workspaceId != workspaceId) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'Merge ObjectType must exist in the supplied workspace.',
      );
    }
    final mergeObjects = await objectStore.listObjects(objectTypeId);
    final mergeObjectsById = <int, AppObject>{
      for (final object in mergeObjects) object.id: object,
    };
    if (!mergeObjectsById.containsKey(survivorObjectId) ||
        !mergeObjectsById.containsKey(retiredObjectId)) {
      throw ArgumentError(
        'Survivor and retired Objects must both currently belong to the supplied ObjectType.',
      );
    }

    final integrity = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
    );
    final report = await integrity.auditWorkspace(workspaceId);
    if (!report.isHealthy) {
      return RelationObjectMergePlan(
        workspaceId: workspaceId,
        objectTypeId: objectTypeId,
        survivorObjectId: survivorObjectId,
        retiredObjectId: retiredObjectId,
        mutations: const <RelationObjectMergeMutation>[],
        relationBlockers: _integrityBlockers(report),
        changedSurvivingSourceObjectIds: const <int>[],
      );
    }

    final objectTypes = await objectStore.listObjectTypes(workspaceId);
    final objectsById = <int, AppObject>{};
    final objectIdsByType = <int, Set<int>>{};
    final relationPropertiesByType = <int, List<ObjectPropertyDefinition>>{};
    final propertiesById = <int, ObjectPropertyDefinition>{};

    for (final type in objectTypes) {
      final objects = await objectStore.listObjects(type.id);
      objectIdsByType[type.id] = objects.map((object) => object.id).toSet();
      for (final object in objects) {
        objectsById[object.id] = object;
      }
      final relationProperties = type.properties
          .where((property) => property.isRelation)
          .toList(growable: false);
      relationPropertiesByType[type.id] = relationProperties;
      for (final property in relationProperties) {
        propertiesById[property.id] = property;
      }
    }

    final currentValues = <int, Map<int, List<int>>>{};
    for (final type in objectTypes) {
      final properties = relationPropertiesByType[type.id]!;
      for (final objectId in objectIdsByType[type.id]!) {
        final object = objectsById[objectId]!;
        final values = <int, List<int>>{};
        for (final property in properties) {
          final inspection = inspectRelationStoredValue(
            object.values[property.id],
          );
          if (inspection.isMalformed) {
            throw StateError(
              'Relation integrity changed while preparing Object merge preview.',
            );
          }
          values[property.id] = List<int>.unmodifiable(
            inspection.value.objectIds,
          );
        }
        currentValues[objectId] = values;
      }
    }

    final blockers = <ObjectMergeRelationBlocker>[];
    final blockerKeys = <String>{};
    void block(String key, String reason) {
      if (!blockerKeys.add(key)) return;
      blockers.add(ObjectMergeRelationBlocker(key: key, reason: reason));
    }

    final finalValues = <int, Map<int, List<int>>>{};
    for (final entry in currentValues.entries) {
      final sourceObjectId = entry.key;
      final next = <int, List<int>>{};
      for (final valueEntry in entry.value.entries) {
        final transformed = _retargetIds(
          valueEntry.value,
          retiredObjectId: retiredObjectId,
          survivorObjectId: survivorObjectId,
        );
        if (_hasDuplicates(transformed)) {
          block(
            'relation:$sourceObjectId:${valueEntry.key}:duplicate-retarget',
            'Retargeting Object $retiredObjectId to $survivorObjectId would create duplicate Relation targets.',
          );
        }
        next[valueEntry.key] = transformed;
      }
      finalValues[sourceObjectId] = next;
    }

    final mergeRelationProperties = relationPropertiesByType[objectTypeId]!;
    for (final property in mergeRelationProperties) {
      final survivorTargets = finalValues[survivorObjectId]![property.id]!;
      final retiredTargets = _retargetIds(
        currentValues[retiredObjectId]![property.id]!,
        retiredObjectId: retiredObjectId,
        survivorObjectId: survivorObjectId,
      );
      if (_hasDuplicates(retiredTargets)) {
        block(
          'relation:${property.id}:retired-outgoing-duplicate',
          'Retired outgoing Relation ${property.name} becomes ambiguous after identity retargeting.',
        );
      }

      List<int> mergedTargets;
      if (survivorTargets.isEmpty) {
        mergedTargets = retiredTargets;
      } else if (retiredTargets.isEmpty ||
          _sameIntList(survivorTargets, retiredTargets)) {
        mergedTargets = survivorTargets;
      } else {
        block(
          'relation:${property.id}:outgoing-conflict',
          'Survivor and retired Objects have different non-empty outgoing values for Relation ${property.name}; Object merge cannot silently union, reorder, or choose one side.',
        );
        mergedTargets = survivorTargets;
      }
      finalValues[survivorObjectId]![property.id] = List<int>.unmodifiable(
        mergedTargets,
      );
      finalValues[retiredObjectId]![property.id] = const <int>[];
    }

    for (final sourceEntry in finalValues.entries) {
      final sourceObjectId = sourceEntry.key;
      final source = objectsById[sourceObjectId]!;
      final sourceType = objectTypes.singleWhere(
        (type) => type.id == source.objectTypeId,
      );
      for (final valueEntry in sourceEntry.value.entries) {
        final property = propertiesById[valueEntry.key]!;
        final targetIds = valueEntry.value;
        if (_hasDuplicates(targetIds)) {
          block(
            'relation:$sourceObjectId:${property.id}:duplicate-final',
            'Object $sourceObjectId would end with duplicate targets for Relation ${property.name}.',
          );
        }
        if (!property.allowsMultipleRelations && targetIds.length > 1) {
          block(
            'relation:$sourceObjectId:${property.id}:cardinality',
            'Object $sourceObjectId would violate single-value cardinality for Relation ${property.name}.',
          );
        }
        final targetTypeId = property.targetObjectTypeId;
        final validTargetIds = targetTypeId == null
            ? const <int>{}
            : objectIdsByType[targetTypeId] ?? const <int>{};
        for (final targetId in targetIds) {
          if (!validTargetIds.contains(targetId)) {
            block(
              'relation:$sourceObjectId:${property.id}:target:$targetId',
              'Relation ${sourceType.name}.${property.name} would target Object $targetId outside its declared target ObjectType.',
            );
          }
        }
      }
    }

    for (final sourceEntry in finalValues.entries) {
      final sourceObjectId = sourceEntry.key;
      if (sourceObjectId == retiredObjectId) continue;
      for (final valueEntry in sourceEntry.value.entries) {
        final property = propertiesById[valueEntry.key]!;
        if (!bidirectionalStore.hasManagedPairMetadata(property)) continue;
        final pair = await bidirectionalStore.pairFor(property);
        if (pair == null) {
          block(
            'relation:$sourceObjectId:${property.id}:pair-metadata',
            'Relation ${property.name} has inconsistent bidirectional pair metadata.',
          );
          continue;
        }
        for (final targetId in valueEntry.value) {
          final inverseTargets =
              finalValues[targetId]?[pair.inverseProperty.id] ?? const <int>[];
          if (!inverseTargets.contains(sourceObjectId)) {
            block(
              'relation:$sourceObjectId:${property.id}:pair-target:$targetId',
              'Object merge would break bidirectional Relation ${property.name} / ${pair.inverseProperty.name}.',
            );
          }
        }
      }
    }

    final mutations = <RelationObjectMergeMutation>[];
    final changedSurvivingSourceIds = <int>{};
    for (final sourceEntry in currentValues.entries) {
      final sourceObjectId = sourceEntry.key;
      for (final valueEntry in sourceEntry.value.entries) {
        final after = finalValues[sourceObjectId]![valueEntry.key]!;
        if (_sameIntList(valueEntry.value, after)) continue;
        mutations.add(
          RelationObjectMergeMutation(
            sourceObjectId: sourceObjectId,
            propertyId: valueEntry.key,
            beforeTargetObjectIds: valueEntry.value,
            afterTargetObjectIds: after,
          ),
        );
        if (sourceObjectId != retiredObjectId) {
          changedSurvivingSourceIds.add(sourceObjectId);
        }
      }
    }
    mutations.sort((left, right) {
      final leftRetired = left.sourceObjectId == retiredObjectId ? 0 : 1;
      final rightRetired = right.sourceObjectId == retiredObjectId ? 0 : 1;
      final retiredCompare = leftRetired.compareTo(rightRetired);
      if (retiredCompare != 0) return retiredCompare;
      final sourceCompare = left.sourceObjectId.compareTo(right.sourceObjectId);
      if (sourceCompare != 0) return sourceCompare;
      return left.propertyId.compareTo(right.propertyId);
    });
    final changedIds = changedSurvivingSourceIds.toList()..sort();

    return RelationObjectMergePlan(
      workspaceId: workspaceId,
      objectTypeId: objectTypeId,
      survivorObjectId: survivorObjectId,
      retiredObjectId: retiredObjectId,
      mutations: mutations,
      relationBlockers: blockers,
      changedSurvivingSourceObjectIds: changedIds,
    );
  }

  Future<RelationObjectMergeImpact> apply(RelationObjectMergePlan plan) async {
    if (!plan.isExecutable) {
      throw StateError(
        'Blocked Relation Object merge plans cannot be applied.',
      );
    }

    return genericStore.database.transaction(() async {
      final fresh = await preview(
        workspaceId: plan.workspaceId,
        objectTypeId: plan.objectTypeId,
        survivorObjectId: plan.survivorObjectId,
        retiredObjectId: plan.retiredObjectId,
      );
      if (!fresh.isExecutable || !_samePlanMutations(plan, fresh)) {
        throw StateError(
          'Relation Object merge plan is stale; preview again before applying.',
        );
      }

      final objectTypes = await objectStore.listObjectTypes(plan.workspaceId);
      final propertiesById = <int, ObjectPropertyDefinition>{
        for (final type in objectTypes)
          for (final property in type.properties)
            if (property.isRelation) property.id: property,
      };

      for (final mutation in fresh.mutations) {
        final property = propertiesById[mutation.propertyId];
        if (property == null) {
          throw StateError(
            'Relation Property ${mutation.propertyId} disappeared during Object merge execution.',
          );
        }
        await mutationService.setRelation(
          objectId: mutation.sourceObjectId,
          property: property,
          targetObjectIds: mutation.afterTargetObjectIds,
        );
      }

      final after = await RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
      ).auditWorkspace(plan.workspaceId);
      if (!after.isHealthy) {
        throw StateError(
          'Relation Object merge execution produced an integrity violation.',
        );
      }
      if ((await objectStore.outgoingRelations(plan.retiredObjectId))
              .isNotEmpty ||
          (await objectStore.backlinks(plan.retiredObjectId)).isNotEmpty) {
        throw StateError(
          'Retired Object still has canonical Relation edges after rewiring.',
        );
      }

      return RelationObjectMergeImpact(
        changedSurvivingSourceObjectIds: fresh.changedSurvivingSourceObjectIds,
      );
    });
  }

  List<ObjectMergeRelationBlocker> _integrityBlockers(
    RelationIntegrityReport report,
  ) {
    final blockers = <ObjectMergeRelationBlocker>[];
    for (var index = 0; index < report.issues.length; index++) {
      final issue = report.issues[index];
      blockers.add(
        ObjectMergeRelationBlocker(
          key:
              'relation-integrity:${issue.kind.name}:${issue.sourceObjectId ?? 0}:${issue.propertyId ?? 0}:${issue.targetObjectId ?? 0}:$index',
          reason: issue.message,
        ),
      );
    }
    return blockers;
  }
}

void _validateIds({
  required int survivorObjectId,
  required int retiredObjectId,
}) {
  if (survivorObjectId <= 0 || retiredObjectId <= 0) {
    throw ArgumentError('Merge Object ids must be positive.');
  }
  if (survivorObjectId == retiredObjectId) {
    throw ArgumentError('Merge survivor and retired Object ids must differ.');
  }
}

List<int> _retargetIds(
  List<int> objectIds, {
  required int retiredObjectId,
  required int survivorObjectId,
}) => List<int>.unmodifiable(
  objectIds.map(
    (objectId) => objectId == retiredObjectId ? survivorObjectId : objectId,
  ),
);

bool _hasDuplicates(List<int> objectIds) =>
    objectIds.toSet().length != objectIds.length;

bool _sameIntList(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _samePlanMutations(
  RelationObjectMergePlan expected,
  RelationObjectMergePlan actual,
) {
  if (expected.workspaceId != actual.workspaceId ||
      expected.objectTypeId != actual.objectTypeId ||
      expected.survivorObjectId != actual.survivorObjectId ||
      expected.retiredObjectId != actual.retiredObjectId ||
      expected.mutations.length != actual.mutations.length) {
    return false;
  }
  for (var index = 0; index < expected.mutations.length; index++) {
    final left = expected.mutations[index];
    final right = actual.mutations[index];
    if (left.sourceObjectId != right.sourceObjectId ||
        left.propertyId != right.propertyId ||
        !_sameIntList(
          left.beforeTargetObjectIds,
          right.beforeTargetObjectIds,
        ) ||
        !_sameIntList(left.afterTargetObjectIds, right.afterTargetObjectIds)) {
      return false;
    }
  }
  return true;
}
