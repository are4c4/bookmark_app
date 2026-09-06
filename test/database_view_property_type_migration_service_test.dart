import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_property_type_migration_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ObjectPropertyDefinition> _property(
  ObjectStore store,
  int objectTypeId,
  int propertyId,
) async =>
    (await store.getObjectType(objectTypeId))!
        .properties
        .singleWhere((property) => property.id == propertyId);

void main() {
  test('select to multiSelect transforms values and preserves stable Property identity', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Task',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Status',
      type: ObjectPropertyType.select,
      config: const <String, dynamic>{
        'options': <String>['Todo', 'Done'],
        'searchable': false,
      },
    );
    final firstId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'First',
    );
    final secondId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Second',
    );
    final property = await _property(objectStore, typeId, propertyId);
    await objectStore.setPropertyValue(
      objectId: firstId,
      property: property,
      value: 'Todo',
    );
    await objectStore.setPropertyValue(
      objectId: secondId,
      property: property,
      value: null,
    );

    final result = await service.applyChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.multiSelect,
    );

    expect(result.property.id, propertyId);
    expect(result.property.type, ObjectPropertyType.multiSelect);
    expect(result.transformedObjectCount, 2);
    final objects = await objectStore.listObjects(typeId);
    final byId = {for (final object in objects) object.id: object};
    expect(byId[firstId]!.values[propertyId], <String>['Todo']);
    expect(byId[secondId]!.values[propertyId], isNull);
    final raw = (await genericStore.listProperties(typeId)).single;
    expect(raw.id, propertyId);
    expect(raw.type, 'multiSelect');
    expect(raw.config['options'], <String>['Todo', 'Done']);
    expect(raw.config['searchable'], isFalse);
  });

  test('multiSelect to select requires exactly the ambiguous Object choices', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Labels',
      type: ObjectPropertyType.multiSelect,
      config: const <String, dynamic>{
        'options': <String>['alpha', 'beta', 'gamma'],
      },
    );
    final singleId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Single',
    );
    final ambiguousId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Ambiguous',
    );
    final property = await _property(objectStore, typeId, propertyId);
    await objectStore.setPropertyValue(
      objectId: singleId,
      property: property,
      value: <String>[' alpha '],
    );
    await objectStore.setPropertyValue(
      objectId: ambiguousId,
      property: property,
      value: <String>['beta', 'gamma'],
    );

    await expectLater(
      service.applyChange(
        objectTypeId: typeId,
        propertyId: propertyId,
        nextType: ObjectPropertyType.select,
      ),
      throwsArgumentError,
    );
    expect(
      (await _property(objectStore, typeId, propertyId)).type,
      ObjectPropertyType.multiSelect,
    );

    await expectLater(
      service.applyChange(
        objectTypeId: typeId,
        propertyId: propertyId,
        nextType: ObjectPropertyType.select,
        multiSelectToSelectChoices: <int, String>{
          ambiguousId: 'beta',
          singleId: 'alpha',
        },
      ),
      throwsArgumentError,
    );
    expect(
      (await _property(objectStore, typeId, propertyId)).type,
      ObjectPropertyType.multiSelect,
    );

    final result = await service.applyChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.select,
      multiSelectToSelectChoices: <int, String>{ambiguousId: 'gamma'},
    );
    expect(result.property.type, ObjectPropertyType.select);
    final objects = await objectStore.listObjects(typeId);
    final byId = {for (final object in objects) object.id: object};
    expect(byId[singleId]!.values[propertyId], 'alpha');
    expect(byId[ambiguousId]!.values[propertyId], 'gamma');
    expect(
      (await genericStore.listProperties(typeId)).single.config['options'],
      <String>['alpha', 'beta', 'gamma'],
    );
  });

  test('invalid explicit narrowing choice rolls back earlier transformed Objects', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Labels',
      type: ObjectPropertyType.multiSelect,
    );
    final firstId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'First',
    );
    final secondId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Second',
    );
    final property = await _property(objectStore, typeId, propertyId);
    await objectStore.setPropertyValue(
      objectId: firstId,
      property: property,
      value: <String>['one'],
    );
    await objectStore.setPropertyValue(
      objectId: secondId,
      property: property,
      value: <String>['two', 'three'],
    );

    await expectLater(
      service.applyChange(
        objectTypeId: typeId,
        propertyId: propertyId,
        nextType: ObjectPropertyType.select,
        multiSelectToSelectChoices: <int, String>{secondId: 'missing'},
      ),
      throwsArgumentError,
    );

    final objects = await objectStore.listObjects(typeId);
    final byId = {for (final object in objects) object.id: object};
    expect(byId[firstId]!.values[propertyId], <String>['one']);
    expect(byId[secondId]!.values[propertyId], <String>['two', 'three']);
    expect(
      (await _property(objectStore, typeId, propertyId)).type,
      ObjectPropertyType.multiSelect,
    );
  });

  test('migration-required number to rating fails closed with old schema and data intact', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Score',
      type: ObjectPropertyType.number,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Invalid',
    );
    final property = await _property(objectStore, typeId, propertyId);
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: property,
      value: 5.5,
    );

    await expectLater(
      service.applyChange(
        objectTypeId: typeId,
        propertyId: propertyId,
        nextType: ObjectPropertyType.rating,
      ),
      throwsStateError,
    );

    expect(
      (await _property(objectStore, typeId, propertyId)).type,
      ObjectPropertyType.number,
    );
    expect(
      (await objectStore.listObjects(typeId)).single.values[propertyId],
      5.5,
    );
  });

  test('number to rating applies only after all values pass preflight', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Score',
      type: ObjectPropertyType.number,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Valid',
    );
    final property = await _property(objectStore, typeId, propertyId);
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: property,
      value: 4.0,
    );

    final result = await service.applyChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.rating,
    );

    expect(result.property.type, ObjectPropertyType.rating);
    expect(result.transformedObjectCount, 1);
    expect(
      (await objectStore.listObjects(typeId)).single.values[propertyId],
      4,
    );
  });

  test('storage-preserving conversion does not rewrite values and drops stale option config', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'URL',
      type: ObjectPropertyType.url,
      config: const <String, dynamic>{
        'options': <String>['stale'],
        'searchable': false,
      },
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Entry',
    );
    final property = await _property(objectStore, typeId, propertyId);
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: property,
      value: 'https://example.com',
    );

    final result = await service.applyChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.text,
    );

    expect(result.transformedObjectCount, 0);
    expect(result.property.type, ObjectPropertyType.text);
    expect(
      (await objectStore.listObjects(typeId)).single.values[propertyId],
      'https://example.com',
    );
    final raw = (await genericStore.listProperties(typeId)).single;
    expect(raw.config.containsKey('options'), isFalse);
    expect(raw.config['searchable'], isFalse);
  });
}
