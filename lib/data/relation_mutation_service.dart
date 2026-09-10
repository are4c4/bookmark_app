import '../domain/object_model.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_index_service.dart';
import 'relation_stored_value_inspector.dart';

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
    if (targetObjectIds.toSet().length != targetObjectIds.length) {
      throw ArgumentError.value(
        targetObjectIds,
        'targetObjectIds',
        'Relation targets must not contain duplicate Object ids.',
      );
    }

    final storedProperty = await _canonicalRelationProperty(property);
    final source = await _objectById(storedProperty.objectTypeId, objectId);
    if (source == null) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'Object does not belong to the Relation source ObjectType.',
      );
    }
    final sourceInspection = inspectRelationStoredValue(
      source.values[storedProperty.id],
    );
    if (sourceInspection.isMalformed) {
      throw StateError(
        'Malformed persisted Relation value for Object $objectId / Relation Property ${storedProperty.id}.',
      );
    }

    final pair = await _pairIfManaged(storedProperty);
    if (pair != null) {
      final relevantTargetIds = <int>{
        ...sourceInspection.value.objectIds,
        ...targetObjectIds,
      };
      final targetTypeId = pair.sourceProperty.targetObjectTypeId!;
      for (final target in await objectStore.listObjects(targetTypeId)) {
        if (!relevantTargetIds.contains(target.id)) continue;
        assertRelationStoredValueWellFormed(
          target.values[pair.inverseProperty.id],
          context:
              'Object ${target.id} / inverse Relation Property ${pair.inverseProperty.id}',
        );
      }
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

  /// Deletes an Object through the canonical Relation-safe lifecycle.
  ///
  /// Existing consumers that do not need downstream projection refresh can
  /// retain this compatibility boundary. Consumers that need exact changed
  /// Object ids should call [deleteObjectWithImpact].
  Future<void> deleteObject({
    required int workspaceId,
    required int objectTypeId,
    required int objectId,
  }) async {
    await deleteObjectWithImpact(
      workspaceId: workspaceId,
      objectTypeId: objectTypeId,
      objectId: objectId,
    );
  }

  /// Deletes an Object after detaching every incoming Relation that references
  /// it, including legacy values that were not yet present in the edge index.
  ///
  /// The returned impact is derived from the same validated detach plan used
  /// for mutation and is exposed only after the deletion transaction commits.
  /// This lets downstream projection owners refresh exact changed Objects
  /// without reimplementing backlink discovery after the target is gone.
  ///
  /// This is the Relation-safe deletion path for Object detail consumers. The
  /// low-level [ObjectStore.deleteObject] remains available for storage-owned
  /// workflows that have already handled relation lifecycle explicitly.
  Future<RelationObjectDeletionImpact> deleteObjectWithImpact({
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
      return RelationObjectDeletionImpact(
        deletedObjectId: objectId,
        detachedSourceObjectIds: const <int>[],
      );
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

      final inspection = inspectRelationStoredValue(source.values[property.id]);
      if (inspection.isMalformed) {
        throw StateError(
          'Malformed persisted Relation value for Object ${source.id} / Relation Property ${property.id}.',
        );
      }
      final nextIds = inspection.value.objectIds
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

    final detachedSourceObjectIds = <int>{
      for (final plan in plans) plan.sourceObjectId,
    }.toList(growable: false);

    // All pair/property/source validation is completed before the first write.
    // Keep every detach plus the final Object deletion in one outer transaction.
    // Nested canonical Relation mutations participate in this transaction, so a
    // late write failure cannot leave earlier backlinks detached while the
    // target Object survives.
    await genericStore.database.transaction(() async {
      for (final plan in plans) {
        await setRelation(
          objectId: plan.sourceObjectId,
          property: plan.property,
          targetObjectIds: plan.targetObjectIds,
        );
      }
      await objectStore.deleteObject(objectId);
    });

    return RelationObjectDeletionImpact(
      deletedObjectId: objectId,
      detachedSourceObjectIds: detachedSourceObjectIds,
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
    if (!bidirectionalStore.hasManagedPairMetadata(property)) return null;

    final pair = await bidirectionalStore.pairFor(property);
    if (pair == null) {
      throw StateError(
        'Relation Property ${property.name} has inconsistent bidirectional metadata.',
      );
    }
    return pair;
  }

  Future<AppObject?> _objectById(int objectTypeId, int objectId) async {
    for (final object in await objectStore.listObjects(objectTypeId)) {
      if (object.id == objectId) return object;
    }
    return null;
  }
}

/// Canonical Relation-safe deletion result for downstream projection owners.
///
/// [detachedSourceObjectIds] contains each surviving source Object whose
/// serialized Relation value changed during the committed deletion exactly
/// once. The deleted Object itself is reported separately.
class RelationObjectDeletionImpact {
  RelationObjectDeletionImpact({
    required this.deletedObjectId,
    required List<int> detachedSourceObjectIds,
  }) : detachedSourceObjectIds = List<int>.unmodifiable(
          detachedSourceObjectIds,
        );

  final int deletedObjectId;
  final List<int> detachedSourceObjectIds;
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
