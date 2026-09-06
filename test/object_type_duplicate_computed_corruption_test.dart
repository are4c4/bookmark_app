import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_management_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicateSchema rolls back when Formula references a missing Property',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Broken computed source',
    );
    await genericStore.createProperty(
      databaseId: sourceId,
      name: 'Broken formula',
      type: 'formula',
      config: const <String, dynamic>{'expression': '{999999} + 1'},
    );

    await expectLater(
      management.duplicateSchema(objectTypeId: sourceId),
      throwsStateError,
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(types.map((type) => type.id).toList(), <int>[sourceId]);
    expect(types.single.name, 'Broken computed source');
  });

  test('duplicateSchema rolls back when Rollup Relation reference is invalid',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Broken rollup source',
    );
    await genericStore.createProperty(
      databaseId: sourceId,
      name: 'Broken rollup',
      type: 'rollup',
      config: const <String, dynamic>{
        'relationPropertyId': 999999,
        'aggregation': 'count',
      },
    );

    await expectLater(
      management.duplicateSchema(objectTypeId: sourceId),
      throwsStateError,
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(types.map((type) => type.id).toList(), <int>[sourceId]);
    expect(types.single.name, 'Broken rollup source');
  });
}
