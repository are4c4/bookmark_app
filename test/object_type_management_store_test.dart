import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_management_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicateSchema copies custom properties and rewrites self relations', () async {
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
      name: 'カテゴリ',
      icon: '🗂️',
    );
    await objectStore.createProperty(
      objectTypeId: sourceId,
      name: '説明',
      type: ObjectPropertyType.text,
    );
    await objectStore.createRelationProperty(
      objectTypeId: sourceId,
      name: '親',
      targetObjectTypeId: sourceId,
      multiple: false,
    );

    final copyId = await management.duplicateSchema(objectTypeId: sourceId);
    final copy = (await objectStore.getObjectType(copyId))!;

    expect(copy.name, 'カテゴリ のコピー');
    expect(copy.icon, '🗂️');
    expect(copy.properties.map((item) => item.name), ['説明', '親']);
    final parent = copy.properties.firstWhere((item) => item.name == '親');
    expect(parent.targetObjectTypeId, copyId);
  });

  test('duplicateSchema does not copy records or stale inverse metadata', () async {
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
      name: '書籍',
    );
    await objectStore.createProperty(
      objectTypeId: sourceId,
      name: '関連',
      type: ObjectPropertyType.objectRelation,
      config: {
        'targetObjectTypeId': sourceId,
        'multiple': true,
        'bidirectional': true,
        'inversePropertyId': 999,
        'pairRole': 'source',
      },
    );
    await objectStore.createObject(objectTypeId: sourceId, title: '既存レコード');

    final copyId = await management.duplicateSchema(objectTypeId: sourceId);
    expect(await objectStore.listObjects(copyId), isEmpty);
    final copy = (await objectStore.getObjectType(copyId))!;
    final relation = copy.properties.single;
    expect(relation.config['bidirectional'], isNull);
    expect(relation.config['inversePropertyId'], isNull);
    expect(relation.config['pairRole'], isNull);
  });

  test('identity editing and deletion reject system ObjectTypes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final system = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'test-system',
      name: 'System',
      icon: '⚙️',
    );

    await expectLater(
      management.updateIdentity(objectTypeId: system.id, name: '変更'),
      throwsStateError,
    );
    await expectLater(
      management.deleteCustomType(system.id),
      throwsStateError,
    );
    await expectLater(
      management.duplicateSchema(objectTypeId: system.id),
      throwsStateError,
    );
  });

  test('custom identity can update name and icon', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final id = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '旧名',
      icon: '◻️',
    );

    await management.updateIdentity(
      objectTypeId: id,
      name: '新名',
      icon: '📦',
    );
    final updated = (await objectStore.getObjectType(id))!;
    expect(updated.name, '新名');
    expect(updated.icon, '📦');
  });
}
