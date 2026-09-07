import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_property_clear_migration_service.dart';
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
  test('explicit clear removes stored values and preserves stable Property id',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Text',
      type: ObjectPropertyType.text,
    );
    final property = await _property(objectStore, typeId, propertyId);
    final firstId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'First',
    );
    final secondId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Second',
    );
    await objectStore.setPropertyValue(
      objectId: firstId,
      property: property,
      value: '12',
    );
    await objectStore.setPropertyValue(
      objectId: secondId,
      property: property,
      value: 'not-a-number',
    );

    final service = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final result = await service.applyChangeClearingStoredValues(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.number,
    );

    expect(result.property.id, propertyId);
    expect(result.property.type, ObjectPropertyType.number);
    expect(result.transformedObjectCount, 2);
    final objects = await objectStore.listObjects(typeId);
    expect(objects.every((object) => !object.values.containsKey(propertyId)), isTrue);
  });

  test('failed schema update rolls cleared values and old Property type back',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Text',
      type: ObjectPropertyType.text,
    );
    final property = await _property(objectStore, typeId, propertyId);
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Entry',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: property,
      value: '12',
    );
    await database.customStatement('''
      CREATE TRIGGER block_property_type_update
      BEFORE UPDATE ON generic_properties
      BEGIN
        SELECT RAISE(ABORT, 'blocked for rollback regression');
      END
    ''');

    final service = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    await expectLater(
      service.applyChangeClearingStoredValues(
        objectTypeId: typeId,
        propertyId: propertyId,
        nextType: ObjectPropertyType.number,
      ),
      throwsA(anything),
    );

    expect(
      (await _property(objectStore, typeId, propertyId)).type,
      ObjectPropertyType.text,
    );
    expect(
      (await objectStore.listObjects(typeId)).single.values[propertyId],
      '12',
    );
  });
}
