import '../domain/object_model.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_index_service.dart';

/// Stable mutation facade for Relation consumers such as Object detail pages.
///
/// Callers may hold stale UI copies of a Property definition. This service
/// always resolves the persisted Property by id before mutating data, and it
/// routes bidirectional pairs through [BidirectionalRelationStore] so inverse
/// values stay synchronized.
class RelationMutationService {
  const RelationMutationService({
    required this.objectStore,
    required this.bidirectionalStore,
    required this.genericStore,
  });

  final ObjectStore objectStore;
  final BidirectionalRelationStore bidirectionalStore;
  final GenericDatabaseStore genericStore;

  Future<void> setRelation({
    required int objectId,
    required ObjectPropertyDefinition property,
    required List<int> targetObjectIds,
  }) async {
    final storedProperty = await _canonicalRelationProperty(property);
    final pair = await _pairIfManaged(storedProperty);
    if (pair != null) {
      await bidirectionalStore.setRelation(
        objectId: objectId,
        property: pair.sourceProperty,
        targetObjectIds: targetObjectIds,
      );
      return;
    }

    await objectStore.setRelation(
      objectId: objectId,
      property: storedProperty,
      targetObjectIds: targetObjectIds,
    );
  }

  Future<ObjectPropertyDefinition> renameRelationProperty({
    required ObjectPropertyDefinition property,
    required String name,
    String? inverseName,
  }) async {
    final storedProperty = await _canonicalRelationProperty(property);
    final sourceType = (await objectStore.getObjectType(
      storedProperty.objectTypeId,
    ))!;
    if (sourceType.kind == ObjectTypeKind.system) {
      throw StateError('System Relation Properties cannot be renamed.');
    }

    final nextName = name.trim();
    if (nextName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Relation Property name is empty.');
    }

    final pair = await _pairIfManaged(storedProperty);
    if (pair != null) {
      return (await bidirectionalStore.renamePair(
        property: pair.sourceProperty,
        propertyName: nextName,
        inversePropertyName: inverseName?.trim().isNotEmpty == true
            ? inverseName!.trim()
            : pair.inverseProperty.name,
      ))
          .sourceProperty;
    }

    for (final candidate in sourceType.properties) {
      if (candidate.id != storedProperty.id && candidate.name == nextName) {
        throw ArgumentError.value(
          nextName,
          'name',
          'A Property with the same name already exists.',
        );
      }
    }

    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: storedProperty.id,
        databaseId: storedProperty.objectTypeId,
        name: nextName,
        type: storedProperty.storageType,
        config: storedProperty.config,
        sortOrder: storedProperty.sortOrder,
      ),
    );
    return _canonicalRelationProperty(storedProperty);
  }

  Future<void> deleteRelationProperty(
    ObjectPropertyDefinition property,
  ) async {
    final storedProperty = await _canonicalRelationProperty(property);
    final pair = await _pairIfManaged(storedProperty);
    if (pair != null) {
      await bidirectionalStore.deletePair(pair.sourceProperty);
      return;
    }

    await objectStore.deleteProperty(storedProperty.id);
  }

  /// Deletes an Object after detaching every incoming Relation that references
  /// it, including legacy values that were not yet present in the edge index.
  ///
  /// This is the Relation-safe deletion path for Object detail consumers. The
  /// low-level [ObjectStore.deleteObject] remains available for storage-owned
  /// workflows that have already handled relation lifecycle explicitly.
  Future<void> deleteObject({
    required int workspaceId,
    required int objectTypeId,
    required int objectId,
  }) async {
    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null || objectType.workspaceId != workspaceId) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'ObjectType must exist in the supplied workspace.',
      );
    }
    final targetExists = (await objectStore.listObjects(objectTypeId))
        .any((object) => object.id == objectId);
    if (!targetExists) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'Object does not belong to ObjectType $objectTypeId.',
      );
    }

    await RelationIndexService(objectStore).rebuildWorkspace(workspaceId);
    final backlinks = await objectStore.backlinks(objectId);
    if (backlinks.isEmpty) {
      await objectStore.deleteObject(objectId);
      return;
    }

    final objectTypes = await objectStore.listObjectTypes(workspaceId);
    final propertiesById = <int, ObjectPropertyDefinition>{};
    for (final type in objectTypes) {
      for (final property in type.properties) {
        if (property.isRelation) propertiesById[property.id] = property;
      }
    }

    final sourceObjectsByType = <int, Map<int, AppObject>>{};
    final plans = <_RelationDetachPlan>[];
    for (final edge in backlinks) {
      final property = propertiesById[edge.propertyId];
      if (property == null) {
        throw StateError(
          'Backlink references missing Relation Property ${edge.propertyId}.',
        );
      }
      await _pairIfManaged(property);

      final sourceObjects = sourceObjectsByType.putIfAbsent(
        property.objectTypeId,
        () => <int, AppObject>{},
      );
      if (sourceObjects.isEmpty) {
        for (final object in await objectStore.listObjects(property.objectTypeId)) {
          sourceObjects[object.id] = object;
        }
      }
      final source = sourceObjects[edge.sourceObjectId];
      if (source == null) {
        throw StateError(
          'Backlink source Object ${edge.sourceObjectId} no longer exists.',
        );
      }

      final nextIds = ObjectRelationValue.fromJson(source.values[property.id])
          .objectIds
          .where((id) => id != objectId)
          .toList(growable: false);
      plans.add(
        _RelationDetachPlan(
          sourceObjectId: source.id,
          property: property,
          targetObjectIds: nextIds,
        ),
      );
    }

    // All pair/property/source validation is completed before the first write.
    // Apply detachments first so no surviving Object stores a deleted id.
    for (final plan in plans) {
      await setRelation(
        objectId: plan.sourceObjectId,
        property: plan.property,
        targetObjectIds: plan.targetObjectIds,
      );
    }
    await objectStore.deleteObject(objectId);
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

    ObjectPropertyDefinition? storedProperty;
    for (final candidate in sourceType.properties) {
      if (candidate.id == property.id) {
        storedProperty = candidate;
        break;
      }
    }
    if (storedProperty == null || !storedProperty.isRelation) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Property is not a persisted Relation Property of its source ObjectType.',
      );
    }
    return storedProperty;
  }

  Future<BidirectionalRelationPair?> _pairIfManaged(
    ObjectPropertyDefinition property,
  ) async {
    final hasPairMetadata = property.config['bidirectional'] == true ||
        property.config['inversePropertyId'] != null;
    if (!hasPairMetadata) return null;

    final pair = await bidirectionalStore.pairFor(property);
    if (pair == null) {
      throw StateError(
        'Relation Property ${property.name} has inconsistent bidirectional metadata.',
      );
    }
    return pair;
  }
}

class _RelationDetachPlan {
  const _RelationDetachPlan({
    required this.sourceObjectId,
    required this.property,
    required this.targetObjectIds,
  });

  final int sourceObjectId;
  final ObjectPropertyDefinition property;
  final List<int> targetObjectIds;
}
