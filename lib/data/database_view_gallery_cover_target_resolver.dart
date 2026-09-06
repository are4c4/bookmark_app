import '../domain/object_model.dart';
import 'database_view_gallery_adapter.dart';
import 'image_object_service.dart';
import 'object_store.dart';
import 'system_object_store.dart';
import 'weblink_object_service.dart';

enum GalleryCoverTargetKind { image, weblink }

class GalleryCoverTarget {
  const GalleryCoverTarget({
    required this.kind,
    required this.objectTypeId,
    required this.objectId,
  });

  final GalleryCoverTargetKind kind;
  final int objectTypeId;
  final int objectId;

  @override
  bool operator ==(Object other) =>
      other is GalleryCoverTarget &&
      other.kind == kind &&
      other.objectTypeId == objectTypeId &&
      other.objectId == objectId;

  @override
  int get hashCode => Object.hash(kind, objectTypeId, objectId);
}

/// Resolves the canonical Object that should provide one Gallery card's media.
///
/// This resolver is intentionally read-only. Relation-backed sources fail
/// closed when schema, target Objects, or the normalized Relation index disagree
/// with the serialized Relation value. Multi Relations use the first persisted
/// Relation position as a deterministic presentation choice; they are never
/// rewritten or reduced to single cardinality from the View path.
class DatabaseViewGalleryCoverTargetResolver {
  const DatabaseViewGalleryCoverTargetResolver({
    required this.objectStore,
    required this.systemObjects,
  });

  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;

  Future<GalleryCoverTarget?> resolve({
    required int sourceObjectTypeId,
    required int sourceObjectId,
    required GalleryCoverSource source,
  }) async {
    if (sourceObjectTypeId <= 0 || sourceObjectId <= 0) return null;
    if (source.kind == GalleryCoverSourceKind.none) return null;

    final sourceType = await objectStore.getObjectType(sourceObjectTypeId);
    if (sourceType == null) return null;
    final sourceObject = await _objectById(sourceObjectTypeId, sourceObjectId);
    if (sourceObject == null) return null;

    if (source.kind == GalleryCoverSourceKind.directImage) {
      final systemKey = await systemObjects.systemKeyForObjectType(
        sourceObjectTypeId,
      );
      if (systemKey != ImageObjectService.systemKey) return null;
      return GalleryCoverTarget(
        kind: GalleryCoverTargetKind.image,
        objectTypeId: sourceObjectTypeId,
        objectId: sourceObjectId,
      );
    }

    final propertyId = source.relationPropertyId;
    if (propertyId == null) return null;
    ObjectPropertyDefinition? property;
    for (final candidate in sourceType.properties) {
      if (candidate.id == propertyId) {
        property = candidate;
        break;
      }
    }
    if (property == null || !property.isRelation) return null;

    final targetObjectTypeId = property.targetObjectTypeId;
    if (targetObjectTypeId == null) return null;
    final targetType = await objectStore.getObjectType(targetObjectTypeId);
    if (targetType == null || targetType.workspaceId != sourceType.workspaceId) {
      return null;
    }

    final expectedSystemKey = switch (source.kind) {
      GalleryCoverSourceKind.imageRelation => ImageObjectService.systemKey,
      GalleryCoverSourceKind.weblinkRelationRepresentativeImage =>
        WeblinkObjectService.systemKey,
      _ => null,
    };
    if (expectedSystemKey == null) return null;
    final actualSystemKey = await systemObjects.systemKeyForObjectType(
      targetObjectTypeId,
    );
    if (actualSystemKey != expectedSystemKey) return null;

    final relation = ObjectRelationValue.fromJson(
      sourceObject.values[property.id],
    );
    if (relation.isEmpty) return null;

    // A View is a reader, never an index repair path. Require the normalized
    // edges to exactly preserve the serialized Relation order before resolving.
    final edges = (await objectStore.outgoingRelations(sourceObjectId))
        .where((edge) => edge.propertyId == property!.id)
        .toList(growable: false)
      ..sort((a, b) => a.position.compareTo(b.position));
    final edgeTargetIds = edges
        .map((edge) => edge.targetObjectId)
        .toList(growable: false);
    if (!_sameIds(edgeTargetIds, relation.objectIds)) return null;

    final targets = await objectStore.listObjects(targetObjectTypeId);
    final byId = <int, AppObject>{for (final target in targets) target.id: target};
    if (relation.objectIds.any((id) => !byId.containsKey(id))) return null;

    final selectedObjectId = relation.objectIds.first;
    return GalleryCoverTarget(
      kind: source.kind == GalleryCoverSourceKind.imageRelation
          ? GalleryCoverTargetKind.image
          : GalleryCoverTargetKind.weblink,
      objectTypeId: targetObjectTypeId,
      objectId: selectedObjectId,
    );
  }

  Future<AppObject?> _objectById(int objectTypeId, int objectId) async {
    final objects = await objectStore.listObjects(objectTypeId);
    for (final object in objects) {
      if (object.id == objectId) return object;
    }
    return null;
  }

  bool _sameIds(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
