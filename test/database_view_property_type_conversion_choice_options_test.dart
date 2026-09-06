import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_property_type_conversion_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MultiSelect narrowing exposes normalized distinct choice values by Object', () async {
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
      name: 'Labels',
      type: ObjectPropertyType.multiSelect,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'A',
    );
    final property = (await objectStore.getObjectType(typeId))!
        .properties
        .singleWhere((candidate) => candidate.id == propertyId);
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: property,
      value: <String>[' alpha ', 'beta', 'alpha', ''],
    );

    final impact = await DatabaseViewPropertyTypeConversionService(objectStore)
        .inspectChange(
      objectTypeId: typeId,
      propertyId: propertyId,
      nextType: ObjectPropertyType.select,
    );

    expect(impact.mode, PropertyTypeConversionMode.requiresExplicitChoice);
    expect(impact.objectsRequiringChoice, <int>[objectId]);
    expect(
      impact.explicitChoiceOptions,
      <int, List<String>>{objectId: <String>['alpha', 'beta']},
    );
  });
}
