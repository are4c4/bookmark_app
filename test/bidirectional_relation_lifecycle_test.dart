import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pairFor resolves both sides of a bidirectional relation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final relations = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '書籍',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '人物',
    );
    final pair = await relations.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: '著者',
      targetObjectTypeId: personTypeId,
      inverseName: '著書',
    );

    final resolved = await relations.pairFor(pair.sourceProperty);
    expect(resolved, isNotNull);
    expect(resolved!.sourceProperty.id, pair.sourceProperty.id);
    expect(resolved.inverseProperty.id, pair.inverseProperty.id);
  });

  test('renamePair updates both names while preserving pair metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final relations = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '書籍',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '人物',
    );
    final pair = await relations.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: '著者',
      targetObjectTypeId: personTypeId,
      inverseName: '著書',
    );

    final renamed = await relations.renamePair(
      property: pair.sourceProperty,
      propertyName: '作者',
      inversePropertyName: '作品',
    );

    expect(renamed.sourceProperty.name, '作者');
    expect(renamed.inverseProperty.name, '作品');
    expect(
      renamed.sourceProperty.config['inversePropertyId'],
      renamed.inverseProperty.id,
    );
    expect(
      renamed.inverseProperty.config['inversePropertyId'],
      renamed.sourceProperty.id,
    );
  });

  test('deletePair removes both relation properties', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final relations = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final projectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'プロジェクト',
    );
    final taskTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'タスク',
    );
    final pair = await relations.createPair(
      sourceObjectTypeId: projectTypeId,
      sourceName: 'タスク',
      targetObjectTypeId: taskTypeId,
      inverseName: 'プロジェクト',
    );

    await relations.deletePair(pair.sourceProperty);

    final projectType = await objectStore.getObjectType(projectTypeId);
    final taskType = await objectStore.getObjectType(taskTypeId);
    expect(projectType!.properties, isEmpty);
    expect(taskType!.properties, isEmpty);
  });

  test('self relation requires distinct property names', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final relations = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final tagTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'タグ',
    );

    await expectLater(
      relations.createPair(
        sourceObjectTypeId: tagTypeId,
        sourceName: '親子',
        targetObjectTypeId: tagTypeId,
        inverseName: '親子',
      ),
      throwsArgumentError,
    );
  });
}
