import '../domain/object_model.dart';
import 'bidirectional_relation_store.dart';
import 'object_store.dart';

enum RelationIntegrityIssueKind {
  missingTargetObjectType,
  crossWorkspaceTarget,
  missingTargetObject,
  cardinalityViolation,
  duplicateTargetObject,
  missingIndexEdge,
  staleIndexEdge,
  indexOrderMismatch,
  invalidBidirectionalPair,
  inverseValueMismatch,
}

class RelationIntegrityIssue {
  const RelationIntegrityIssue({
    required this.kind,
    required this.message,
    this.objectTypeId,
    this.propertyId,
    this.sourceObjectId,
    this.targetObjectId,
  });

  final RelationIntegrityIssueKind kind;
  final String message;
  final int? objectTypeId;
  final int? propertyId;
  final int? sourceObjectId;
  final int? targetObjectId;
}

class RelationIntegrityReport {
  const RelationIntegrityReport({required this.issues});

  final List<RelationIntegrityIssue> issues;

  bool get isHealthy => issues.isEmpty;

  Iterable<RelationIntegrityIssue> issuesOf(RelationIntegrityIssueKind kind) =>
      issues.where((issue) => issue.kind == kind);
}

/// Read-only audit of persisted Relation values, normalized edge indexes, and
/// bidirectional metadata.
///
/// This service never mutates user data. Repair remains an explicit separate
/// action (for example [ObjectStore.rebuildRelationIndex]) so callers can show
/// diagnostics before deciding how to reconcile legacy/inconsistent state.
class RelationIntegrityService {
  const RelationIntegrityService({
    required this.objectStore,
    required this.bidirectionalStore,
  });

  final ObjectStore objectStore;
  final BidirectionalRelationStore bidirectionalStore;

  Future<RelationIntegrityReport> auditWorkspace(int workspaceId) async {
    final issues = <RelationIntegrityIssue>[];
    final objectTypes = await objectStore.listObjectTypes(workspaceId);
    final objectsByType = <int, List<AppObject>>{};
    final outgoingByObject = <int, List<ObjectRelationEdge>>{};

    Future<List<AppObject>> objectsFor(int objectTypeId) async {
      final cached = objectsByType[objectTypeId];
      if (cached != null) return cached;
      final objects = await objectStore.listObjects(objectTypeId);
      objectsByType[objectTypeId] = objects;
      return objects;
    }

    Future<List<ObjectRelationEdge>> outgoingFor(int objectId) async {
      final cached = outgoingByObject[objectId];
      if (cached != null) return cached;
      final edges = await objectStore.outgoingRelations(objectId);
      outgoingByObject[objectId] = edges;
      return edges;
    }

    for (final sourceType in objectTypes) {
      final sourceObjects = await objectsFor(sourceType.id);
      final relationProperties = sourceType.properties
          .where((item) => item.isRelation)
          .toList(growable: false);
      final relationPropertyIds = relationProperties
          .map((property) => property.id)
          .toSet();
      for (final property in relationProperties) {
        final targetTypeId = property.targetObjectTypeId;
        if (targetTypeId == null) {
          issues.add(
            RelationIntegrityIssue(
              kind: RelationIntegrityIssueKind.missingTargetObjectType,
              objectTypeId: sourceType.id,
              propertyId: property.id,
              message:
                  'Relation Property ${sourceType.name}.${property.name} has no target ObjectType.',
            ),
          );
          continue;
        }

        final targetType = await objectStore.getObjectType(targetTypeId);
        if (targetType == null) {
          issues.add(
            RelationIntegrityIssue(
              kind: RelationIntegrityIssueKind.missingTargetObjectType,
              objectTypeId: sourceType.id,
              propertyId: property.id,
              message:
                  'Relation Property ${sourceType.name}.${property.name} targets missing ObjectType $targetTypeId.',
            ),
          );
          continue;
        }
        if (targetType.workspaceId != workspaceId) {
          issues.add(
            RelationIntegrityIssue(
              kind: RelationIntegrityIssueKind.crossWorkspaceTarget,
              objectTypeId: sourceType.id,
              propertyId: property.id,
              message:
                  'Relation Property ${sourceType.name}.${property.name} targets ObjectType $targetTypeId in another workspace.',
            ),
          );
          continue;
        }

        final targetObjects = await objectsFor(targetTypeId);
        final validTargetIds = targetObjects.map((object) => object.id).toSet();

        BidirectionalRelationPair? pair;
        if (bidirectionalStore.hasManagedPairMetadata(property)) {
          pair = await bidirectionalStore.pairFor(property);
          if (pair == null) {
            issues.add(
              RelationIntegrityIssue(
                kind: RelationIntegrityIssueKind.invalidBidirectionalPair,
                objectTypeId: sourceType.id,
                propertyId: property.id,
                message:
                    'Relation Property ${sourceType.name}.${property.name} has inconsistent bidirectional metadata.',
              ),
            );
          }
        }

        for (final source in sourceObjects) {
          final rawStoredObjectIds = _rawPersistedRelationObjectIds(
            source.values[property.id],
          );
          final storedValue = ObjectRelationValue.fromJson(
            source.values[property.id],
          );
          final storedObjectIds = storedValue.objectIds;
          final storedIds = storedObjectIds.toSet();
          if (!property.allowsMultipleRelations && storedObjectIds.length > 1) {
            issues.add(
              RelationIntegrityIssue(
                kind: RelationIntegrityIssueKind.cardinalityViolation,
                objectTypeId: sourceType.id,
                propertyId: property.id,
                sourceObjectId: source.id,
                message:
                    'Object ${source.id} stores ${storedObjectIds.length} targets for single Relation ${property.name}.',
              ),
            );
          }

          final seenTargetIds = <int>{};
          final duplicateTargetIds = <int>{};
          for (final targetId in rawStoredObjectIds) {
            if (!seenTargetIds.add(targetId)) {
              duplicateTargetIds.add(targetId);
            }
          }
          for (final targetId in duplicateTargetIds) {
            issues.add(
              RelationIntegrityIssue(
                kind: RelationIntegrityIssueKind.duplicateTargetObject,
                objectTypeId: sourceType.id,
                propertyId: property.id,
                sourceObjectId: source.id,
                targetObjectId: targetId,
                message:
                    'Object ${source.id} stores duplicate Relation target $targetId for ${property.name}.',
              ),
            );
          }

          final indexedEdges = (await outgoingFor(source.id))
              .where((edge) => edge.propertyId == property.id)
              .toList(growable: false);
          final indexedIds = indexedEdges
              .map((edge) => edge.targetObjectId)
              .toSet();

          for (final targetId in storedIds) {
            if (!validTargetIds.contains(targetId)) {
              issues.add(
                RelationIntegrityIssue(
                  kind: RelationIntegrityIssueKind.missingTargetObject,
                  objectTypeId: sourceType.id,
                  propertyId: property.id,
                  sourceObjectId: source.id,
                  targetObjectId: targetId,
                  message:
                      'Object ${source.id} stores missing Relation target $targetId for ${property.name}.',
                ),
              );
            }
            if (!indexedIds.contains(targetId)) {
              issues.add(
                RelationIntegrityIssue(
                  kind: RelationIntegrityIssueKind.missingIndexEdge,
                  objectTypeId: sourceType.id,
                  propertyId: property.id,
                  sourceObjectId: source.id,
                  targetObjectId: targetId,
                  message:
                      'Relation value ${source.id} -> $targetId for ${property.name} is missing from the normalized edge index.',
                ),
              );
            }
          }

          for (final targetId in indexedIds.difference(storedIds)) {
            issues.add(
              RelationIntegrityIssue(
                kind: RelationIntegrityIssueKind.staleIndexEdge,
                objectTypeId: sourceType.id,
                propertyId: property.id,
                sourceObjectId: source.id,
                targetObjectId: targetId,
                message:
                    'Relation edge ${source.id} -> $targetId for ${property.name} is not present in the persisted Property value.',
              ),
            );
          }

          final hasMatchingIndexedTargets =
              storedIds.length == indexedIds.length &&
              storedIds.containsAll(indexedIds);
          final hasDuplicatePersistedTargets =
              rawStoredObjectIds.length != storedObjectIds.length;
          if (hasMatchingIndexedTargets &&
              !hasDuplicatePersistedTargets &&
              !_hasCanonicalIndexOrder(
                storedObjectIds: storedObjectIds,
                indexedEdges: indexedEdges,
              )) {
            issues.add(
              RelationIntegrityIssue(
                kind: RelationIntegrityIssueKind.indexOrderMismatch,
                objectTypeId: sourceType.id,
                propertyId: property.id,
                sourceObjectId: source.id,
                message:
                    'Relation edge order for Object ${source.id} and ${property.name} does not match the persisted Relation value.',
              ),
            );
          }

          if (pair != null) {
            final targetsById = {
              for (final target in targetObjects) target.id: target,
            };
            for (final targetId in storedIds.intersection(validTargetIds)) {
              final target = targetsById[targetId]!;
              final inverseIds = ObjectRelationValue.fromJson(
                target.values[pair.inverseProperty.id],
              ).objectIds;
              if (!inverseIds.contains(source.id)) {
                issues.add(
                  RelationIntegrityIssue(
                    kind: RelationIntegrityIssueKind.inverseValueMismatch,
                    objectTypeId: sourceType.id,
                    propertyId: property.id,
                    sourceObjectId: source.id,
                    targetObjectId: targetId,
                    message:
                        'Bidirectional Relation ${property.name} points to $targetId but inverse ${pair.inverseProperty.name} does not contain ${source.id}.',
                  ),
                );
              }
            }
          }
        }
      }

      for (final source in sourceObjects) {
        final strayEdges = (await outgoingFor(source.id))
            .where((edge) => !relationPropertyIds.contains(edge.propertyId));
        for (final edge in strayEdges) {
          issues.add(
            RelationIntegrityIssue(
              kind: RelationIntegrityIssueKind.staleIndexEdge,
              objectTypeId: sourceType.id,
              propertyId: edge.propertyId,
              sourceObjectId: source.id,
              targetObjectId: edge.targetObjectId,
              message:
                  'Relation edge ${source.id} -> ${edge.targetObjectId} references Property ${edge.propertyId}, which is not a current Relation Property of ObjectType ${sourceType.id}.',
            ),
          );
        }
      }
    }

    return RelationIntegrityReport(issues: List.unmodifiable(issues));
  }
}

bool _hasCanonicalIndexOrder({
  required List<int> storedObjectIds,
  required List<ObjectRelationEdge> indexedEdges,
}) {
  if (storedObjectIds.length != indexedEdges.length) return false;
  for (var index = 0; index < storedObjectIds.length; index++) {
    final edge = indexedEdges[index];
    if (edge.targetObjectId != storedObjectIds[index] ||
        edge.position != index) {
      return false;
    }
  }
  return true;
}

List<int> _rawPersistedRelationObjectIds(dynamic value) {
  if (value is int) return <int>[value];
  if (value is List) {
    return value
        .map((item) => item is int ? item : int.tryParse('$item'))
        .whereType<int>()
        .toList(growable: false);
  }
  if (value is Map) {
    final raw = value['objectIds'];
    if (raw is List) return _rawPersistedRelationObjectIds(raw);
  }
  return const <int>[];
}
