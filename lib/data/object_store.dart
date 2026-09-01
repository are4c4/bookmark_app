import '../domain/object_model.dart';
import 'generic_database_store.dart';

class ObjectStore {
  ObjectStore(this._genericStore);

  final GenericDatabaseStore _genericStore;

  Future<List<AppObjectType>> listObjectTypes(int workspaceId) async {
    final definitions = await _genericStore.listDatabases(workspaceId);
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

  Future<void> renameObjectType(int id, String name) =>
      _genericStore.renameDatabase(id, name);

  Future<void> deleteObjectType(int id) => _genericStore.deleteDatabase(id);

  Future<int> createProperty({
    required int objectTypeId,
    required String name,
    required ObjectPropertyType type,
    Map<String, dynamic> config = const <String, dynamic>{},
  }) {
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
  }) {
    return createProperty(
      objectTypeId: objectTypeId,
      name: name,
      type: ObjectPropertyType.objectRelation,
      config: <String, dynamic>{
        'targetObjectTypeId': targetObjectTypeId,
        'multiple': multiple,
      },
    );
  }

  Future<void> deleteProperty(int id) => _genericStore.deleteProperty(id);

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
      final relation = value is ObjectRelationValue
          ? value
          : ObjectRelationValue.fromJson(value);
      await _validateRelation(property, relation);
      await _genericStore.setValue(
        recordId: objectId,
        propertyId: property.id,
        value: relation.toJson(multiple: property.allowsMultipleRelations),
      );
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

  Future<AppObjectType> _hydrateObjectType(
    GenericDatabaseDefinitionRecord definition,
  ) async {
    final properties = await _genericStore.listProperties(definition.id);
    return AppObjectType(
      id: definition.id,
      workspaceId: definition.workspaceId,
      name: definition.name,
      icon: definition.icon,
      kind: ObjectTypeKind.custom,
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
