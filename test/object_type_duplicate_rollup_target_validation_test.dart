import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_management_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicateSchema rejects non-numeric external Rollup targets atomically',
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

    final targetId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final textId = await objectStore.createProperty(
      objectTypeId: targetId,
      name: 'Text',
      type: ObjectPropertyType.text,
    );
    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceId,
      name: 'Targets',
      targetObjectTypeId: targetId,
    );
    await genericStore.createProperty(
      databaseId: sourceId,
      name: 'Broken sum',
      type: 'rollup',
      config: <String, dynamic>{
        'relationPropertyId': relationId,
        'targetPropertyId': textId,
        'aggregation': 'sum',
      },
    );

    await expectLater(
      management.duplicateSchema(objectTypeId: sourceId),
      throwsStateError,
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(types.map((type) => type.id).toSet(), <int>{targetId, sourceId});
  });

  test('duplicateSchema rejects missing external Rollup targets atomically',
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

    final targetId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceId,
      name: 'Targets',
      targetObjectTypeId: targetId,
    );
    await genericStore.createProperty(
      databaseId: sourceId,
      name: 'Broken sum',
      type: 'rollup',
      config: <String, dynamic>{
        'relationPropertyId': relationId,
        'targetPropertyId': 999999,
        'aggregation': 'sum',
      },
    );

    await expectLater(
      management.duplicateSchema(objectTypeId: sourceId),
      throwsStateError,
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(types.map((type) => type.id).toSet(), <int>{targetId, sourceId});
  });

  test('duplicateSchema rejects numeric Rollups missing targetPropertyId',
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

    final targetId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceId,
      name: 'Targets',
      targetObjectTypeId: targetId,
    );
    await genericStore.createProperty(
      databaseId: sourceId,
      name: 'Broken average',
      type: 'rollup',
      config: <String, dynamic>{
        'relationPropertyId': relationId,
        'aggregation': 'average',
      },
    );

    await expectLater(
      management.duplicateSchema(objectTypeId: sourceId),
      throwsStateError,
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(types.map((type) => type.id).toSet(), <int>{targetId, sourceId});
  });
}
