import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_property_type_conversion_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
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
  test('preserving and widening Value conversions are classified without mutation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeConversionService(objectStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final urlId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'URL',
      type: ObjectPropertyType.url,
    );
    final ratingId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Rating',
      type: ObjectPropertyType.rating,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'A',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: await _property(objectStore, typeId, urlId),
      value: 'https://example.com',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: await _property(objectStore, typeId, ratingId),
      value: 4,
    );

    final urlImpact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: urlId,
      nextType: ObjectPropertyType.text,
    );
    final ratingImpact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: ratingId,
      nextType: ObjectPropertyType.number,
    );

    expect(urlImpact.mode, PropertyTypeConversionMode.preserveStoredValues);
    expect(urlImpact.objectsWithStoredValue, 1);
    expect(ratingImpact.mode, PropertyTypeConversionMode.preserveStoredValues);
    final reloaded = (await objectStore.listObjects(typeId)).single;
    expect(reloaded.values[urlId], 'https://example.com');
    expect(reloaded.values[ratingId], 4);
    expect((await _property(objectStore, typeId, urlId)).type, ObjectPropertyType.url);
  });

  test('select to multiSelect is transformable but malformed historical values require migration', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeConversionService(objectStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Status',
      type: ObjectPropertyType.select,
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

    var impact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.multiSelect,
    );
    expect(impact.mode, PropertyTypeConversionMode.transformStoredValues);
    expect(impact.objectsRequiringMigration, isEmpty);

    await genericStore.setValue(
      recordId: secondId,
      propertyId: propertyId,
      value: <String>['legacy', 'shape'],
    );
    impact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.multiSelect,
    );
    expect(impact.mode, PropertyTypeConversionMode.requiresMigration);
    expect(impact.objectsRequiringMigration, [secondId]);
  });

  test('multiSelect to select surfaces ambiguous Objects separately from corrupt values', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeConversionService(objectStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Labels',
      type: ObjectPropertyType.multiSelect,
    );
    final oneId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'One',
    );
    final ambiguousId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Ambiguous',
    );
    final corruptId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Corrupt',
    );
    final property = await _property(objectStore, typeId, propertyId);
    await objectStore.setPropertyValue(
      objectId: oneId,
      property: property,
      value: <String>['alpha'],
    );
    await objectStore.setPropertyValue(
      objectId: ambiguousId,
      property: property,
      value: <String>['alpha', 'beta'],
    );

    var impact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.select,
    );
    expect(impact.mode, PropertyTypeConversionMode.requiresExplicitChoice);
    expect(impact.objectsRequiringChoice, [ambiguousId]);
    expect(impact.objectsRequiringMigration, isEmpty);

    await genericStore.setValue(
      recordId: corruptId,
      propertyId: propertyId,
      value: <dynamic>['ok', 7],
    );
    impact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.select,
    );
    expect(impact.mode, PropertyTypeConversionMode.requiresMigration);
    expect(impact.objectsRequiringChoice, [ambiguousId]);
    expect(impact.objectsRequiringMigration, [corruptId]);
  });

  test('number to rating validates every stored value before calling it transformable', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeConversionService(objectStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Score',
      type: ObjectPropertyType.number,
    );
    final goodId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Good',
    );
    final badId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Bad',
    );
    final property = await _property(objectStore, typeId, propertyId);
    await objectStore.setPropertyValue(
      objectId: goodId,
      property: property,
      value: 5,
    );

    var impact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.rating,
    );
    expect(impact.mode, PropertyTypeConversionMode.transformStoredValues);

    await objectStore.setPropertyValue(
      objectId: badId,
      property: property,
      value: 5.5,
    );
    impact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.rating,
    );
    expect(impact.mode, PropertyTypeConversionMode.requiresMigration);
    expect(impact.objectsRequiringMigration, [badId]);
  });

  test('unrelated shapes and Relation destinations remain explicit rather than coerced', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertyTypeConversionService(objectStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final textId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Text',
      type: ObjectPropertyType.text,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'A',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: await _property(objectStore, typeId, textId),
      value: '12',
    );

    final numberImpact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: textId,
      nextType: ObjectPropertyType.number,
    );
    final relationImpact = await service.inspectChange(
      objectTypeId: typeId,
      propertyId: textId,
      nextType: ObjectPropertyType.objectRelation,
    );

    expect(numberImpact.mode, PropertyTypeConversionMode.requiresMigration);
    expect(numberImpact.objectsRequiringMigration, [objectId]);
    expect(relationImpact.mode, PropertyTypeConversionMode.incompatible);
  });

  test('system ObjectType retyping fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final type = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'system-test',
      name: 'System',
      icon: '⚙️',
    );
    final property = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Name',
      type: ObjectPropertyType.text,
    );
    final service = DatabaseViewPropertyTypeConversionService(objectStore);

    await expectLater(
      service.inspectChange(
        objectTypeId: type.id,
        propertyId: property.id,
        nextType: ObjectPropertyType.number,
      ),
      throwsStateError,
    );
  });
}
