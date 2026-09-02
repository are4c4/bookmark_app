import '../domain/object_model.dart';
import 'object_store.dart';

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

/// Resolves relation-index edges into stable Object/Property references for UI
/// consumers without exposing generic table details.
class RelationReadService {
  const RelationReadService(this.objectStore);

  final ObjectStore objectStore;

  Future<List<ResolvedRelationBacklink>> backlinks({
    required int workspaceId,
    required int targetObjectId,
  }) async {
    final edges = await objectStore.backlinks(targetObjectId);
    if (edges.isEmpty) return const <ResolvedRelationBacklink>[];

    final objectTypes = await objectStore.listObjectTypes(workspaceId);
    final propertiesById = <int, ObjectPropertyDefinition>{};
    for (final type in objectTypes) {
      for (final property in type.properties) {
        if (property.isRelation) propertiesById[property.id] = property;
      }
    }

    final sourceIdsByType = <int, Set<int>>{};
    for (final edge in edges) {
      final property = propertiesById[edge.propertyId];
      if (property == null) continue;
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

    final result = <ResolvedRelationBacklink>[];
    for (final edge in edges) {
      final property = propertiesById[edge.propertyId];
      final source = sourcesById[edge.sourceObjectId];
      if (property == null || source == null) continue;
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
    final relationProperties = <int, ObjectPropertyDefinition>{
      for (final property in sourceType.properties)
        if (property.isRelation) property.id: property,
    };

    final edges = await objectStore.outgoingRelations(sourceObjectId);
    if (edges.isEmpty) return const <ResolvedOutgoingRelation>[];

    final idsByTargetType = <int, Set<int>>{};
    for (final edge in edges) {
      final property = relationProperties[edge.propertyId];
      final targetTypeId = property?.targetObjectTypeId;
      if (targetTypeId == null) continue;
      idsByTargetType
          .putIfAbsent(targetTypeId, () => <int>{})
          .add(edge.targetObjectId);
    }

    final targetsById = <int, AppObject>{};
    for (final entry in idsByTargetType.entries) {
      final objects = await objectStore.listObjects(entry.key);
      for (final object in objects) {
        if (entry.value.contains(object.id)) targetsById[object.id] = object;
      }
    }

    final result = <ResolvedOutgoingRelation>[];
    for (final edge in edges) {
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
}
