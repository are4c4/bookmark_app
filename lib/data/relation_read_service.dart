import '../domain/object_model.dart';
import 'object_store.dart';
import 'relation_stored_value_inspector.dart';

class ResolvedRelationBacklink {
  const ResolvedRelationBacklink({
    required this.edge,
    required this.property,
    required this.sourceObject,
  });

  final ObjectRelationEdge edge;
  final ObjectPropertyDefinition property;
  final AppObject sourceObject;
}

class ResolvedOutgoingRelation {
  const ResolvedOutgoingRelation({
    required this.edge,
    required this.property,
    required this.targetObject,
  });

  final ObjectRelationEdge edge;
  final ObjectPropertyDefinition property;
  final AppObject targetObject;
}

class RelationNeighborhood {
  const RelationNeighborhood({
    required this.outgoing,
    required this.backlinks,
  });

  final List<ResolvedOutgoingRelation> outgoing;
  final List<ResolvedRelationBacklink> backlinks;

  bool get isEmpty => outgoing.isEmpty && backlinks.isEmpty;
}

/// Returns whether one persisted Relation Property agrees exactly with its
/// normalized edge projection.
///
/// This is intentionally pure/read-only so presentation loaders can share the
/// same fail-closed contract as [RelationReadService] without repairing or
/// normalizing corrupted persisted values.
bool relationStoredValueMatchesEdges({
  required AppObject source,
  required ObjectPropertyDefinition property,
  required List<ObjectRelationEdge> edges,
}) {
  final inspection = inspectRelationStoredValue(source.values[property.id]);
  if (inspection.isMalformed) return false;

  final storedIds = inspection.value.objectIds;
  if (inspection.rawObjectIds.length != storedIds.length) return false;
  if (!property.allowsMultipleRelations && storedIds.length > 1) return false;
  if (storedIds.length != edges.length) return false;

  for (var index = 0; index < storedIds.length; index++) {
    final edge = edges[index];
    if (edge.targetObjectId != storedIds[index] || edge.position != index) {
      return false;
    }
  }
  return true;
}

/// Resolves relation-index edges into stable Object/Property references for UI
/// consumers without exposing generic table details.
///
/// This is a read-only projection, not a repair path. A Relation Property is
/// exposed only when its persisted value is well-formed, exactly agrees with
/// its normalized edge targets/order, and every referenced target still exists
/// in the declared target ObjectType. Corrupt or drifting Properties therefore
/// fail closed until an explicit integrity/reconcile workflow handles them.
class RelationReadService {
  const RelationReadService(this.objectStore);

  final ObjectStore objectStore;

  /// Loads both directions around one Object for Object detail / Daily Note
  /// surfaces without forcing callers to coordinate two different APIs.
  Future<RelationNeighborhood> neighborhood({
    required int workspaceId,
    required int objectTypeId,
    required int objectId,
  }) async {
    final outgoingRelations = await outgoing(
      sourceObjectTypeId: objectTypeId,
      sourceObjectId: objectId,
    );
    final incomingRelations = await backlinks(
      workspaceId: workspaceId,
      targetObjectId: objectId,
    );
    return RelationNeighborhood(
      outgoing: List.unmodifiable(outgoingRelations),
      backlinks: List.unmodifiable(incomingRelations),
    );
  }

  Future<List<ResolvedRelationBacklink>> backlinks({
    required int workspaceId,
    required int targetObjectId,
  }) async {
    final edges = await objectStore.backlinks(targetObjectId);
    if (edges.isEmpty) return const <ResolvedRelationBacklink>[];

    final objectTypes = await objectStore.listObjectTypes(workspaceId);
    final objectTypesById = <int, AppObjectType>{
      for (final type in objectTypes) type.id: type,
    };
    final propertiesById = <int, ObjectPropertyDefinition>{};
    for (final type in objectTypes) {
      for (final property in type.properties) {
        if (property.isRelation) propertiesById[property.id] = property;
      }
    }

    final targetIdsByType = <int, Set<int>>{};
    Future<Set<int>> targetIdsFor(int objectTypeId) async {
      final cached = targetIdsByType[objectTypeId];
      if (cached != null) return cached;
      final ids = (await objectStore.listObjects(objectTypeId))
          .map((object) => object.id)
          .toSet();
      targetIdsByType[objectTypeId] = ids;
      return ids;
    }

    final sourceIdsByType = <int, Set<int>>{};
    for (final edge in edges) {
      final property = propertiesById[edge.propertyId];
      final targetTypeId = property?.targetObjectTypeId;
      if (property == null ||
          targetTypeId == null ||
          !objectTypesById.containsKey(targetTypeId) ||
          !(await targetIdsFor(targetTypeId)).contains(targetObjectId)) {
        continue;
      }
      sourceIdsByType
          .putIfAbsent(property.objectTypeId, () => <int>{})
          .add(edge.sourceObjectId);
    }

    final sourcesById = <int, AppObject>{};
    for (final entry in sourceIdsByType.entries) {
      final objects = await objectStore.listObjects(entry.key);
      for (final object in objects) {
        if (entry.value.contains(object.id)) sourcesById[object.id] = object;
      }
    }

    final outgoingBySource = <int, List<ObjectRelationEdge>>{};
    final result = <ResolvedRelationBacklink>[];
    for (final edge in edges) {
      final property = propertiesById[edge.propertyId];
      final source = sourcesById[edge.sourceObjectId];
      final targetTypeId = property?.targetObjectTypeId;
      if (property == null || source == null || targetTypeId == null) continue;
      if (!objectTypesById.containsKey(targetTypeId)) continue;
      final targetIds = await targetIdsFor(targetTypeId);
      if (!targetIds.contains(targetObjectId)) continue;

      final sourceEdges = outgoingBySource.putIfAbsent(
        source.id,
        () => <ObjectRelationEdge>[],
      );
      if (sourceEdges.isEmpty) {
        sourceEdges.addAll(await objectStore.outgoingRelations(source.id));
      }
      final propertyEdges = sourceEdges
          .where((candidate) => candidate.propertyId == property.id)
          .toList(growable: false);
      if (!relationStoredValueMatchesEdges(
        source: source,
        property: property,
        edges: propertyEdges,
      )) {
        continue;
      }
      if (propertyEdges.any((candidate) => !targetIds.contains(candidate.targetObjectId))) {
        continue;
      }

      result.add(
        ResolvedRelationBacklink(
          edge: edge,
          property: property,
          sourceObject: source,
        ),
      );
    }
    return result;
  }

  Future<List<ResolvedOutgoingRelation>> outgoing({
    required int sourceObjectTypeId,
    required int sourceObjectId,
  }) async {
    final sourceType = await objectStore.getObjectType(sourceObjectTypeId);
    if (sourceType == null) return const <ResolvedOutgoingRelation>[];
    final sourceObject = await _objectById(sourceObjectTypeId, sourceObjectId);
    if (sourceObject == null) return const <ResolvedOutgoingRelation>[];

    final relationProperties = <int, ObjectPropertyDefinition>{
      for (final property in sourceType.properties)
        if (property.isRelation) property.id: property,
    };

    final edges = await objectStore.outgoingRelations(sourceObjectId);
    if (edges.isEmpty) return const <ResolvedOutgoingRelation>[];

    final targetObjectsByType = <int, Map<int, AppObject>>{};
    Future<Map<int, AppObject>> targetsFor(int objectTypeId) async {
      final cached = targetObjectsByType[objectTypeId];
      if (cached != null) return cached;
      final targets = <int, AppObject>{
        for (final object in await objectStore.listObjects(objectTypeId))
          object.id: object,
      };
      targetObjectsByType[objectTypeId] = targets;
      return targets;
    }

    final validPropertyIds = <int>{};
    final targetsById = <int, AppObject>{};
    for (final property in relationProperties.values) {
      final targetTypeId = property.targetObjectTypeId;
      if (targetTypeId == null) continue;
      final targetType = await objectStore.getObjectType(targetTypeId);
      if (targetType == null || targetType.workspaceId != sourceType.workspaceId) {
        continue;
      }

      final propertyEdges = edges
          .where((edge) => edge.propertyId == property.id)
          .toList(growable: false);
      if (!relationStoredValueMatchesEdges(
        source: sourceObject,
        property: property,
        edges: propertyEdges,
      )) {
        continue;
      }
      final targets = await targetsFor(targetTypeId);
      if (propertyEdges.any((edge) => !targets.containsKey(edge.targetObjectId))) {
        continue;
      }
      validPropertyIds.add(property.id);
      for (final edge in propertyEdges) {
        targetsById[edge.targetObjectId] = targets[edge.targetObjectId]!;
      }
    }

    final result = <ResolvedOutgoingRelation>[];
    for (final edge in edges) {
      if (!validPropertyIds.contains(edge.propertyId)) continue;
      final property = relationProperties[edge.propertyId];
      final target = targetsById[edge.targetObjectId];
      if (property == null || target == null) continue;
      result.add(
        ResolvedOutgoingRelation(
          edge: edge,
          property: property,
          targetObject: target,
        ),
      );
    }
    return result;
  }

  Future<AppObject?> _objectById(int objectTypeId, int objectId) async {
    for (final object in await objectStore.listObjects(objectTypeId)) {
      if (object.id == objectId) return object;
    }
    return null;
  }
}
