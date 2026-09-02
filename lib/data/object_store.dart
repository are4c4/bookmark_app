import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'generic_database_store.dart';

class ObjectStore {
  ObjectStore(this._genericStore);

  final GenericDatabaseStore _genericStore;
  Future<void>? _relationSchemaReady;

  Future<void> ensureRelationIndexSchema() => _relationSchemaReady ??=
      _genericStore.database.transaction(() async {
        await _genericStore.ensureSchema();
        await _genericStore.database.customStatement('''
          CREATE TABLE IF NOT EXISTS object_relation_edges (
            source_object_id INTEGER NOT NULL
              REFERENCES generic_records(id) ON DELETE CASCADE,
            property_id INTEGER NOT NULL
              REFERENCES generic_properties(id) ON DELETE CASCADE,
            target_object_id INTEGER NOT NULL
              REFERENCES generic_records(id) ON DELETE CASCADE,
            position INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(source_object_id, property_id, target_object_id)
          )
        ''');
        await _genericStore.database.customStatement(
          'CREATE INDEX IF NOT EXISTS object_relation_edges_target_idx '
          'ON object_relation_edges(target_object_id, property_id, source_object_id)',
        );
        await _genericStore.database.customStatement(
          'CREATE INDEX IF NOT EXISTS object_relation_edges_source_idx '
          'ON object_relation_edges(source_object_id, property_id, position)',
        );
      });

  Future<List<AppObjectType>> listObjectTypes(int workspaceId) async {
    final definitions = await _genericStore.listAllDatabases(workspaceId);
    final result = <AppObjectType>[];
    for (final definition in definitions) {
      result.add(await _hydrateObjectType(definition));
    }
    return result;
  }

  Future<AppObjectType?> getObjectType(int id) async {
    final definition = await _genericStore.getDatabase(id);
    if (definition == null) return null;
    return _hydrateObjectType(definition);
  }

  Future<int> createObjectType({
    required int workspaceId,
    required String name,
    String icon = '◻️',
  }) {
    return _genericStore.createDatabase(
      workspaceId: workspaceId,
      name: name,
      icon: icon,
    );
  }

  Future<void> renameObjectType(int id, String name) async {
    await _assertSchemaMutable(id);
    await _genericStore.renameDatabase(id, name);
  }

  Future<void> deleteObjectType(int id) async {
    await _assertSchemaMutable(id);
    await _assertNoIncomingRelationProperties(id);
    await _genericStore.deleteDatabase(id);
  }

  Future<int> createProperty({
    required int objectTypeId,
    required String name,
    required ObjectPropertyType type,
    Map<String, dynamic> config = const <String, dynamic>{},
    bool allowSystemMutation = false,
  }) async {
    if (!allowSystemMutation) await _assertSchemaMutable(objectTypeId);
    final storageType = ObjectPropertyDefinition(
      id: -1,
      objectTypeId: objectTypeId,
      name: name,
      type: type,
      sortOrder: 0,
      config: config,
    ).storageType;
    return _genericStore.createProperty(
      databaseId: objectTypeId,
      name: name,
      type: storageType,
      config: config,
    );
  }

  Future<int> createRelationProperty({
    required int objectTypeId,
    required String name,
    required int targetObjectTypeId,
    bool multiple = true,
    bool allowSystemMutation = false,
  }) async {
    final sourceType = await getObjectType(objectTypeId);
    final targetType = await getObjectType(targetObjectTypeId);
    if (sourceType == null || targetType == null) {
      throw ArgumentError(
        'Relation source and target ObjectTypes must both exist.',
      );
    }
    if (sourceType.workspaceId != targetType.workspaceId) {
      throw ArgumentError(
        'Relation source and target ObjectTypes must belong to the same workspace.',
      );
    }

    return createProperty(
      objectTypeId: objectTypeId,
      name: name,
      type: ObjectPropertyType.objectRelation,
      config: <String, dynamic>{
        'targetObjectTypeId': targetObjectTypeId,
        'multiple': multiple,
      },
      allowSystemMutation: allowSystemMutation,
    );
  }

  Future<void> deleteProperty(
    int id, {
    bool allowSystemMutation = false,
  }) async {
    if (!allowSystemMutation) {
      final property = await _propertyById(id);
      if (property != null) await _assertSchemaMutable(property.objectTypeId);
    }
    await _genericStore.deleteProperty(id);
  }

  Future<List<AppObject>> listObjects(int objectTypeId) async {
    final records = await _genericStore.listRecords(objectTypeId);
    return records.map(_mapObject).toList(growable: false);
  }

  Future<int> createObject({
    required int objectTypeId,
    required String title,
  }) {
    return _genericStore.createRecord(databaseId: objectTypeId, title: title);
  }

  Future<void> renameObject(int id, String title) =>
      _genericStore.renameRecord(id, title);

  Future<void> deleteObject(int id) => _genericStore.deleteRecord(id);

  Future<void> setPropertyValue({
    required int objectId,
    required ObjectPropertyDefinition property,
    required dynamic value,
  }) async {
    if (property.isRelation) {
      await _validateRelationSource(objectId: objectId, property: property);
      final relation = value is ObjectRelationValue
          ? value
          : ObjectRelationValue.fromJson(value);
      await _validateRelation(property, relation);
      await ensureRelationIndexSchema();
      await _genericStore.database.transaction(() async {
        await _genericStore.setValue(
          recordId: objectId,
          propertyId: property.id,
          value: relation.toJson(multiple: property.allowsMultipleRelations),
        );
        await _replaceRelationEdges(
          objectId: objectId,
          propertyId: property.id,
          targetObjectIds: relation.objectIds,
        );
      });
      return;
    }

    await _genericStore.setValue(
      recordId: objectId,
      propertyId: property.id,
      value: value,
    );
  }

  Future<void> setRelation({
    required int objectId,
    required ObjectPropertyDefinition property,
    required List<int> targetObjectIds,
  }) {
    return setPropertyValue(
      objectId: objectId,
      property: property,
      value: ObjectRelationValue(objectIds: targetObjectIds),
    );
  }

  Future<List<AppObject>> resolveRelation(
    ObjectPropertyDefinition property,
    dynamic storedValue,
  ) async {
    if (!property.isRelation) return const <AppObject>[];
    final targetTypeId = property.targetObjectTypeId;
    if (targetTypeId == null) return const <AppObject>[];

    final relation = ObjectRelationValue.fromJson(storedValue);
    if (relation.isEmpty) return const <AppObject>[];
    final ids = relation.objectIds.toSet();
    final objects = await listObjects(targetTypeId);
    return objects.where((object) => ids.contains(object.id)).toList(growable: false);
  }

  Future<List<ObjectRelationEdge>> outgoingRelations(int objectId) async {
    await ensureRelationIndexSchema();
    final rows = await _genericStore.database.customSelect(
      '''SELECT source_object_id, property_id, target_object_id, position
         FROM object_relation_edges
         WHERE source_object_id = ?
         ORDER BY property_id, position, target_object_id''',
      variables: [Variable<int>(objectId)],
    ).get();
    return rows.map(_mapRelationEdge).toList(growable: false);
  }

  Future<List<ObjectRelationEdge>> backlinks(int targetObjectId) async {
    await ensureRelationIndexSchema();
    final rows = await _genericStore.database.customSelect(
      '''SELECT source_object_id, property_id, target_object_id, position
         FROM object_relation_edges
         WHERE target_object_id = ?
         ORDER BY property_id, source_object_id, position''',
      variables: [Variable<int>(targetObjectId)],
    ).get();
    return rows.map(_mapRelationEdge).toList(growable: false);
  }

  Future<void> rebuildRelationIndex(int objectTypeId) async {
    await ensureRelationIndexSchema();
    final type = await getObjectType(objectTypeId);
    if (type == null) return;
    final relationProperties = type.properties.where((property) => property.isRelation).toList();
    if (relationProperties.isEmpty) return;
    final relationPropertyIds = relationProperties.map((property) => property.id).toSet();
    final objects = await listObjects(objectTypeId);

    await _genericStore.database.transaction(() async {
      for (final object in objects) {
        for (final property in relationProperties) {
          final relation = ObjectRelationValue.fromJson(object.values[property.id]);
          await _replaceRelationEdges(
            objectId: object.id,
            propertyId: property.id,
            targetObjectIds: relation.objectIds,
          );
        }
      }
      if (objects.isEmpty) return;
      final objectIds = objects.map((object) => object.id).toList();
      final objectPlaceholders = List.filled(objectIds.length, '?').join(',');
      final propertyPlaceholders = List.filled(relationPropertyIds.length, '?').join(',');
      await _genericStore.database.customStatement(
        '''DELETE FROM object_relation_edges
           WHERE source_object_id IN ($objectPlaceholders)
             AND property_id NOT IN ($propertyPlaceholders)''',
        [...objectIds, ...relationPropertyIds],
      );
    });
  }

  Future<void> _replaceRelationEdges({
    required int objectId,
    required int propertyId,
    required List<int> targetObjectIds,
  }) async {
    await _genericStore.database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      [objectId, propertyId],
    );
    for (var position = 0; position < targetObjectIds.length; position++) {
      await _genericStore.database.customStatement(
        '''INSERT INTO object_relation_edges(
             source_object_id, property_id, target_object_id, position
           ) VALUES (?, ?, ?, ?)''',
        [objectId, propertyId, targetObjectIds[position], position],
      );
    }
  }

  ObjectRelationEdge _mapRelationEdge(QueryRow row) => ObjectRelationEdge(
        sourceObjectId: row.read<int>('source_object_id'),
        propertyId: row.read<int>('property_id'),
        targetObjectId: row.read<int>('target_object_id'),
        position: row.read<int>('position'),
      );

  Future<ObjectTypeKind> _kindForObjectType(int objectTypeId) async {
    final registry = await _genericStore.database.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'system_object_types' LIMIT 1",
    ).getSingleOrNull();
    if (registry == null) return ObjectTypeKind.custom;
    final row = await _genericStore.database.customSelect(
      'SELECT 1 FROM system_object_types WHERE object_type_id = ? LIMIT 1',
      variables: [Variable<int>(objectTypeId)],
    ).getSingleOrNull();
    return row == null ? ObjectTypeKind.custom : ObjectTypeKind.system;
  }

  Future<void> _assertSchemaMutable(int objectTypeId) async {
    if (await _kindForObjectType(objectTypeId) == ObjectTypeKind.system) {
      throw StateError('System ObjectTypes are managed by the application and cannot be modified.');
    }
  }

  Future<void> _assertNoIncomingRelationProperties(int objectTypeId) async {
    final targetType = await getObjectType(objectTypeId);
    if (targetType == null) return;
    final types = await listObjectTypes(targetType.workspaceId);
    for (final type in types) {
      if (type.id == objectTypeId) continue;
      for (final property in type.properties) {
        if (property.isRelation && property.targetObjectTypeId == objectTypeId) {
          throw StateError(
            'Cannot delete ObjectType ${targetType.name} while Relation Property '
            '${type.name}.${property.name} targets it.',
          );
        }
      }
    }
  }

  Future<ObjectPropertyDefinition?> _propertyById(int propertyId) async {
    final row = await _genericStore.database.customSelect(
      '''SELECT id, database_id, name, type, config_json, sort_order
         FROM generic_properties WHERE id = ? LIMIT 1''',
      variables: [Variable<int>(propertyId)],
    ).getSingleOrNull();
    if (row == null) return null;
    final type = await getObjectType(row.read<int>('database_id'));
    if (type == null) return null;
    for (final property in type.properties) {
      if (property.id == propertyId) return property;
    }
    return null;
  }

  Future<AppObjectType> _hydrateObjectType(
    GenericDatabaseDefinitionRecord definition,
  ) async {
    final properties = await _genericStore.listProperties(definition.id);
    final kind = await _kindForObjectType(definition.id);
    return AppObjectType(
      id: definition.id,
      workspaceId: definition.workspaceId,
      name: definition.name,
      icon: definition.icon,
      kind: kind,
      sortOrder: definition.sortOrder,
      properties: properties.map(_mapProperty).toList(growable: false),
    );
  }

  ObjectPropertyDefinition _mapProperty(GenericPropertyRecord property) {
    return ObjectPropertyDefinition(
      id: property.id,
      objectTypeId: property.databaseId,
      name: property.name,
      type: ObjectPropertyDefinition.fromStorageType(property.type),
      sortOrder: property.sortOrder,
      config: property.config,
    );
  }

  AppObject _mapObject(GenericRecord record) {
    return AppObject(
      id: record.id,
      objectTypeId: record.databaseId,
      title: record.title,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      values: record.values,
    );
  }

  Future<void> _validateRelationSource({
    required int objectId,
    required ObjectPropertyDefinition property,
  }) async {
    final storedProperty = await _propertyById(property.id);
    if (storedProperty == null ||
        !storedProperty.isRelation ||
        storedProperty.objectTypeId != property.objectTypeId) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Relation property must belong to its declared source ObjectType.',
      );
    }

    final sourceExists = (await listObjects(property.objectTypeId))
        .any((object) => object.id == objectId);
    if (!sourceExists) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'Source Object must belong to ObjectType ${property.objectTypeId}.',
      );
    }
  }

  Future<void> _validateRelation(
    ObjectPropertyDefinition property,
    ObjectRelationValue relation,
  ) async {
    final targetTypeId = property.targetObjectTypeId;
    if (targetTypeId == null) {
      throw StateError('Relation property ${property.name} has no target object type.');
    }
    if (!property.allowsMultipleRelations && relation.objectIds.length > 1) {
      throw ArgumentError.value(
        relation.objectIds,
        'targetObjectIds',
        '${property.name} accepts only one related object.',
      );
    }

    final validIds = (await listObjects(targetTypeId)).map((item) => item.id).toSet();
    final invalidIds = relation.objectIds.where((id) => !validIds.contains(id)).toList();
    if (invalidIds.isNotEmpty) {
      throw ArgumentError.value(
        invalidIds,
        'targetObjectIds',
        'Relation targets must belong to object type $targetTypeId.',
      );
    }
  }
}
