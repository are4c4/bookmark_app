import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'generic_database_store.dart';
import 'object_store.dart';

class BidirectionalRelationPair {
  const BidirectionalRelationPair({
    required this.sourceProperty,
    required this.inverseProperty,
  });

  final ObjectPropertyDefinition sourceProperty;
  final ObjectPropertyDefinition inverseProperty;
}

class BidirectionalRelationStore {
  BidirectionalRelationStore({
    required this.genericStore,
    required this.objectStore,
  });

  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;

  Future<BidirectionalRelationPair> createPair({
    required int sourceObjectTypeId,
    required String sourceName,
    required int targetObjectTypeId,
    required String inverseName,
    bool sourceMultiple = true,
    bool inverseMultiple = true,
  }) async {
    final sourceType = await objectStore.getObjectType(sourceObjectTypeId);
    final targetType = await objectStore.getObjectType(targetObjectTypeId);
    if (sourceType == null || targetType == null) {
      throw ArgumentError('Both ObjectTypes must exist.');
    }
    if (sourceType.kind == ObjectTypeKind.system ||
        targetType.kind == ObjectTypeKind.system) {
      throw StateError(
        'Bidirectional user relations can only modify custom ObjectTypes.',
      );
    }

    final normalizedSourceName = sourceName.trim();
    final normalizedInverseName = inverseName.trim();
    if (normalizedSourceName.isEmpty || normalizedInverseName.isEmpty) {
      throw ArgumentError('Relation property names cannot be empty.');
    }
    await _assertPropertyNameAvailable(sourceType, normalizedSourceName);
    await _assertPropertyNameAvailable(
      targetType,
      normalizedInverseName,
      additionallyReservedName:
          sourceObjectTypeId == targetObjectTypeId ? normalizedSourceName : null,
    );

    return genericStore.database.transaction(() async {
      final sourceId = await objectStore.createRelationProperty(
        objectTypeId: sourceObjectTypeId,
        name: normalizedSourceName,
        targetObjectTypeId: targetObjectTypeId,
        multiple: sourceMultiple,
      );
      final inverseId = await objectStore.createRelationProperty(
        objectTypeId: targetObjectTypeId,
        name: normalizedInverseName,
        targetObjectTypeId: sourceObjectTypeId,
        multiple: inverseMultiple,
      );

      await _linkPropertyPair(
        propertyId: sourceId,
        inversePropertyId: inverseId,
        pairRole: 'source',
      );
      await _linkPropertyPair(
        propertyId: inverseId,
        inversePropertyId: sourceId,
        pairRole: 'inverse',
      );

      final refreshedSource =
          (await objectStore.getObjectType(sourceObjectTypeId))!;
      final refreshedTarget =
          (await objectStore.getObjectType(targetObjectTypeId))!;
      return BidirectionalRelationPair(
        sourceProperty: refreshedSource.properties
            .firstWhere((property) => property.id == sourceId),
        inverseProperty: refreshedTarget.properties
            .firstWhere((property) => property.id == inverseId),
      );
    });
  }

  Future<BidirectionalRelationPair?> pairFor(
    ObjectPropertyDefinition property,
  ) async {
    if (!property.isRelation || property.config['bidirectional'] != true) {
      return null;
    }
    final inversePropertyId = _intConfig(property.config['inversePropertyId']);
    final targetTypeId = property.targetObjectTypeId;
    if (inversePropertyId == null || targetTypeId == null) return null;

    final targetType = await objectStore.getObjectType(targetTypeId);
    if (targetType == null) return null;
    ObjectPropertyDefinition? inverse;
    for (final candidate in targetType.properties) {
      if (candidate.id == inversePropertyId) {
        inverse = candidate;
        break;
      }
    }
    if (inverse == null || !inverse.isRelation) return null;
    if (_intConfig(inverse.config['inversePropertyId']) != property.id) {
      return null;
    }

    return BidirectionalRelationPair(
      sourceProperty: property,
      inverseProperty: inverse,
    );
  }

  Future<BidirectionalRelationPair> renamePair({
    required ObjectPropertyDefinition property,
    required String propertyName,
    required String inversePropertyName,
  }) async {
    final pair = await pairFor(property);
    if (pair == null) {
      throw StateError('The Relation property is not a valid bidirectional pair.');
    }

    final nextPropertyName = propertyName.trim();
    final nextInverseName = inversePropertyName.trim();
    if (nextPropertyName.isEmpty || nextInverseName.isEmpty) {
      throw ArgumentError('Relation property names cannot be empty.');
    }

    final sourceType = await objectStore.getObjectType(
      pair.sourceProperty.objectTypeId,
    );
    final inverseType = await objectStore.getObjectType(
      pair.inverseProperty.objectTypeId,
    );
    if (sourceType == null || inverseType == null) {
      throw StateError('A paired ObjectType no longer exists.');
    }
    await _assertPropertyNameAvailable(
      sourceType,
      nextPropertyName,
      exceptPropertyId: pair.sourceProperty.id,
    );
    await _assertPropertyNameAvailable(
      inverseType,
      nextInverseName,
      exceptPropertyId: pair.inverseProperty.id,
      additionallyReservedName:
          sourceType.id == inverseType.id && nextPropertyName != nextInverseName
              ? nextPropertyName
              : null,
    );

    await genericStore.database.transaction(() async {
      await _renameProperty(pair.sourceProperty.id, nextPropertyName);
      await _renameProperty(pair.inverseProperty.id, nextInverseName);
    });

    final refreshedSource = (await objectStore.getObjectType(sourceType.id))!;
    final refreshedInverse = (await objectStore.getObjectType(inverseType.id))!;
    return BidirectionalRelationPair(
      sourceProperty: refreshedSource.properties
          .firstWhere((candidate) => candidate.id == pair.sourceProperty.id),
      inverseProperty: refreshedInverse.properties
          .firstWhere((candidate) => candidate.id == pair.inverseProperty.id),
    );
  }

  Future<void> deletePair(ObjectPropertyDefinition property) async {
    final pair = await pairFor(property);
    if (pair == null) {
      throw StateError('The Relation property is not a valid bidirectional pair.');
    }

    await genericStore.database.transaction(() async {
      await objectStore.deleteProperty(pair.sourceProperty.id);
      if (pair.inverseProperty.id != pair.sourceProperty.id) {
        await objectStore.deleteProperty(pair.inverseProperty.id);
      }
    });
  }

  Future<void> setRelation({
    required int objectId,
    required ObjectPropertyDefinition property,
    required List<int> targetObjectIds,
  }) async {
    if (!property.isRelation) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Property is not a relation.',
      );
    }
    final inversePropertyId = _intConfig(property.config['inversePropertyId']);
    if (inversePropertyId == null) {
      await objectStore.setRelation(
        objectId: objectId,
        property: property,
        targetObjectIds: targetObjectIds,
      );
      return;
    }

    final source = await _objectById(property.objectTypeId, objectId);
    if (source == null) {
      throw ArgumentError.value(objectId, 'objectId', 'Object does not exist.');
    }
    final targetTypeId = property.targetObjectTypeId;
    if (targetTypeId == null) {
      throw StateError('Relation property has no target ObjectType.');
    }
    final targetType = await objectStore.getObjectType(targetTypeId);
    if (targetType == null) {
      throw StateError('Target ObjectType does not exist.');
    }
    final inverseProperty = targetType.properties
        .firstWhere((candidate) => candidate.id == inversePropertyId);

    final oldIds = ObjectRelationValue.fromJson(source.values[property.id])
        .objectIds
        .toSet();
    final nextIds = targetObjectIds.toSet();
    final removed = oldIds.difference(nextIds);
    final added = nextIds.difference(oldIds);

    await genericStore.database.transaction(() async {
      if (!inverseProperty.allowsMultipleRelations) {
        for (final targetId in added) {
          final target = await _objectById(targetTypeId, targetId);
          if (target == null) continue;
          final current = ObjectRelationValue.fromJson(
            target.values[inverseProperty.id],
          ).objectIds;
          if (current.isNotEmpty && !current.contains(objectId)) {
            throw StateError(
              'Inverse relation ${inverseProperty.name} accepts only one Object.',
            );
          }
        }
      }

      await objectStore.setRelation(
        objectId: objectId,
        property: property,
        targetObjectIds: targetObjectIds,
      );

      for (final targetId in removed) {
        final target = await _objectById(targetTypeId, targetId);
        if (target == null) continue;
        final ids = ObjectRelationValue.fromJson(
          target.values[inverseProperty.id],
        ).objectIds.toSet()
          ..remove(objectId);
        await objectStore.setRelation(
          objectId: targetId,
          property: inverseProperty,
          targetObjectIds: ids.toList(growable: false),
        );
      }

      for (final targetId in added) {
        final target = await _objectById(targetTypeId, targetId);
        if (target == null) continue;
        final ids = ObjectRelationValue.fromJson(
          target.values[inverseProperty.id],
        ).objectIds.toSet();
        if (!inverseProperty.allowsMultipleRelations) ids.clear();
        ids.add(objectId);
        await objectStore.setRelation(
          objectId: targetId,
          property: inverseProperty,
          targetObjectIds: ids.toList(growable: false),
        );
      }
    });
  }

  Future<void> _linkPropertyPair({
    required int propertyId,
    required int inversePropertyId,
    required String pairRole,
  }) async {
    final property = await _propertyById(propertyId);
    if (property == null) {
      throw StateError('Relation property $propertyId was not created.');
    }
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: property.id,
        databaseId: property.databaseId,
        name: property.name,
        type: property.type,
        sortOrder: property.sortOrder,
        config: <String, dynamic>{
          ...property.config,
          'bidirectional': true,
          'inversePropertyId': inversePropertyId,
          'pairRole': pairRole,
        },
      ),
    );
  }

  Future<void> _renameProperty(int propertyId, String name) async {
    final property = await _propertyById(propertyId);
    if (property == null) {
      throw StateError('Relation property $propertyId does not exist.');
    }
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: property.id,
        databaseId: property.databaseId,
        name: name,
        type: property.type,
        sortOrder: property.sortOrder,
        config: property.config,
      ),
    );
  }

  Future<void> _assertPropertyNameAvailable(
    AppObjectType objectType,
    String name, {
    int? exceptPropertyId,
    String? additionallyReservedName,
  }) async {
    if (additionallyReservedName != null &&
        additionallyReservedName == name &&
        exceptPropertyId == null) {
      throw ArgumentError.value(
        name,
        'name',
        'Relation property names must be distinct in the same ObjectType.',
      );
    }
    for (final property in objectType.properties) {
      if (property.id == exceptPropertyId) continue;
      if (property.name == name) {
        throw ArgumentError.value(
          name,
          'name',
          'A property with the same name already exists.',
        );
      }
    }
  }

  Future<GenericPropertyRecord?> _propertyById(int propertyId) async {
    final row = await genericStore.database.customSelect(
      'SELECT database_id FROM generic_properties WHERE id = ? LIMIT 1',
      variables: [Variable<int>(propertyId)],
    ).getSingleOrNull();
    if (row == null) return null;
    final properties = await genericStore.listProperties(
      row.read<int>('database_id'),
    );
    for (final property in properties) {
      if (property.id == propertyId) return property;
    }
    return null;
  }

  Future<AppObject?> _objectById(int objectTypeId, int objectId) async {
    final objects = await objectStore.listObjects(objectTypeId);
    for (final object in objects) {
      if (object.id == objectId) return object;
    }
    return null;
  }

  int? _intConfig(dynamic value) =>
      value is int ? value : int.tryParse('$value');
}
