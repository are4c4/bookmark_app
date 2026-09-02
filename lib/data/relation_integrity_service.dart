import '../domain/object_model.dart';
import 'bidirectional_relation_store.dart';
import 'object_store.dart';

enum RelationIntegrityIssueKind {
  missingTargetObjectType,
  crossWorkspaceTarget,
  missingTargetObject,
  missingIndexEdge,
  staleIndexEdge,
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

    Future<List<AppObject>> objectsFor(int objectTypeId) async {
      final cached = objectsByType[objectTypeId];
      if (cached != null) return cached;
      final objects = await objectStore.listObjects(objectTypeId);
      objectsByType[objectTypeId] = objects;
      return objects;
    }

    for (final sourceType in objectTypes) {
      final sourceObjects = await objectsFor(sourceType.id);
      for (final property in sourceType.properties.where((item) => item.isRelation)) {
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

        final hasPairMetadata = property.config['bidirectional'] == true ||
            property.config['inversePropertyId'] != null;
        BidirectionalRelationPair? pair;
        if (hasPairMetadata) {
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
          final storedIds = ObjectRelationValue.fromJson(
            source.values[property.id],
          ).objectIds.toSet();
          final indexedIds = (await objectStore.outgoingRelations(source.id))
              .where((edge) => edge.propertyId == property.id)
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

          if (pair != null && property.config['pairRole'] == 'source') {
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
    }

    return RelationIntegrityReport(issues: List.unmodifiable(issues));
  }
}
