import '../domain/object_model.dart';
import 'generic_database_store.dart';
import 'object_store.dart';

/// Integrity boundary for user-driven Relation target/cardinality changes.
///
/// This service deliberately performs all validation before changing the
/// persisted Property definition. Existing Relation values and normalized
/// edges are never rewritten by schema-only changes.
class RelationSchemaEvolutionService {
  const RelationSchemaEvolutionService({
    required this.objectStore,
    required this.genericStore,
  });

  final ObjectStore objectStore;
  final GenericDatabaseStore genericStore;

  Future<ObjectPropertyDefinition> changeRelationSchema({
    required ObjectPropertyDefinition property,
    required int targetObjectTypeId,
    required bool multiple,
  }) async {
    final storedProperty = await _canonicalRelationProperty(property);
    final sourceType = await objectStore.getObjectType(
      storedProperty.objectTypeId,
    );
    if (sourceType == null) {
      throw StateError('Relation source ObjectType no longer exists.');
    }
    if (sourceType.kind == ObjectTypeKind.system) {
      throw StateError('System Relation Properties cannot be schema-migrated.');
    }
    if (_hasBidirectionalMetadata(storedProperty)) {
      throw StateError(
        'Bidirectional Relation schema changes require an explicit paired migration.',
      );
    }

    final targetType = await objectStore.getObjectType(targetObjectTypeId);
    if (targetType == null || targetType.workspaceId != sourceType.workspaceId) {
      throw ArgumentError.value(
        targetObjectTypeId,
        'targetObjectTypeId',
        'Relation target ObjectType must exist in the source workspace.',
      );
    }

    final sourceObjects = await objectStore.listObjects(sourceType.id);
    final values = <ObjectRelationValue>[];
    final referencedTargetIds = <int>{};
    for (final object in sourceObjects) {
      final relation = ObjectRelationValue.fromJson(
        object.values[storedProperty.id],
      );
      values.add(relation);
      referencedTargetIds.addAll(relation.objectIds);
    }

    if (!multiple) {
      final hasAmbiguousValue = values.any(
        (relation) => relation.objectIds.length > 1,
      );
      if (hasAmbiguousValue) {
        throw StateError(
          'Cannot change a multi Relation to single while an Object stores multiple targets. '
          'An explicit target choice is required.',
        );
      }
    }

    if (referencedTargetIds.isNotEmpty) {
      final validTargetIds = (await objectStore.listObjects(targetObjectTypeId))
          .map((object) => object.id)
          .toSet();
      final invalidTargetIds = referencedTargetIds.difference(validTargetIds);
      if (invalidTargetIds.isNotEmpty) {
        throw StateError(
          'Cannot change Relation target ObjectType because existing targets do not belong '
          'to ObjectType $targetObjectTypeId: ${invalidTargetIds.toList()..sort()}',
        );
      }
    }

    if (storedProperty.targetObjectTypeId == targetObjectTypeId &&
        storedProperty.allowsMultipleRelations == multiple) {
      return storedProperty;
    }

    final nextConfig = <String, dynamic>{
      ...storedProperty.config,
      'targetObjectTypeId': targetObjectTypeId,
      'multiple': multiple,
    };
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: storedProperty.id,
        databaseId: storedProperty.objectTypeId,
        name: storedProperty.name,
        type: storedProperty.storageType,
        config: nextConfig,
        sortOrder: storedProperty.sortOrder,
      ),
    );

    return _canonicalRelationProperty(storedProperty);
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
      if (candidate.id == property.id && candidate.isRelation) {
        return candidate;
      }
    }
    throw ArgumentError.value(
      property.id,
      'property',
      'Property is not a persisted Relation Property of its source ObjectType.',
    );
  }

  bool _hasBidirectionalMetadata(ObjectPropertyDefinition property) =>
      property.config['bidirectional'] == true ||
      property.config['inversePropertyId'] != null;
}
