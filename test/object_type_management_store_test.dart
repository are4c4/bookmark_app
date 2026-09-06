import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/object_type_management_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
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

  test('duplicateSchema preserves interleaved Value and Relation Property order',
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
      name: 'Ordered',
    );
    await objectStore.createRelationProperty(
      objectTypeId: sourceId,
      name: '親',
      targetObjectTypeId: sourceId,
      multiple: false,
    );
    await objectStore.createProperty(
      objectTypeId: sourceId,
      name: '説明',
      type: ObjectPropertyType.text,
    );
    await objectStore.createRelationProperty(
      objectTypeId: sourceId,
      name: '関連',
      targetObjectTypeId: sourceId,
    );
    await objectStore.createProperty(
      objectTypeId: sourceId,
      name: '評価',
      type: ObjectPropertyType.number,
    );

    final copyId = await management.duplicateSchema(objectTypeId: sourceId);
    final copy = (await objectStore.getObjectType(copyId))!;

    expect(
      copy.properties.map((item) => item.name).toList(),
      <String>['親', '説明', '関連', '評価'],
    );
    expect(copy.properties.map((item) => item.sortOrder).toList(), <int>[0, 1, 2, 3]);
  });

  test('duplicateSchema remaps reusable defaults and preserves Body template',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '記事',
    );
    final summaryId = await objectStore.createProperty(
      objectTypeId: sourceId,
      name: '概要',
      type: ObjectPropertyType.text,
    );
    final parentId = await objectStore.createRelationProperty(
      objectTypeId: sourceId,
      name: '親記事',
      targetObjectTypeId: sourceId,
      multiple: false,
    );
    await defaultsStore.write(
      objectTypeId: sourceId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[summaryId, parentId],
        propertyOrder: <int>[parentId, summaryId],
        openMode: ObjectOpenMode.centerPeek,
        bodyTemplate: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'notes',
              type: 'paragraph',
              text: '初期メモ',
            ),
          ],
        ),
      ),
    );

    final copyId = await management.duplicateSchema(objectTypeId: sourceId);
    final copy = (await objectStore.getObjectType(copyId))!;
    final copySummary = copy.properties.firstWhere((item) => item.name == '概要');
    final copyParent = copy.properties.firstWhere((item) => item.name == '親記事');
    final copyDefaults = await defaultsStore.read(copyId);

    expect(copyDefaults, isNotNull);
    expect(
      copyDefaults!.visiblePropertyIds,
      <int>[copySummary.id, copyParent.id],
    );
    expect(
      copyDefaults.propertyOrder,
      <int>[copyParent.id, copySummary.id],
    );
    expect(copyDefaults.openMode, ObjectOpenMode.centerPeek);
    expect(copyDefaults.bodyTemplate?.blocks.single.id, 'notes');
    expect(copyDefaults.bodyTemplate?.blocks.single.text, '初期メモ');
    expect(copyDefaults.visiblePropertyIds, isNot(contains(summaryId)));
    expect(copyDefaults.visiblePropertyIds, isNot(contains(parentId)));
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
