import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paired relation properties point to each other', () async {
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
      sourceMultiple: true,
      inverseMultiple: true,
    );

    expect(pair.sourceProperty.config['bidirectional'], true);
    expect(
      pair.sourceProperty.config['inversePropertyId'],
      pair.inverseProperty.id,
    );
    expect(
      pair.inverseProperty.config['inversePropertyId'],
      pair.sourceProperty.id,
    );
    expect(pair.sourceProperty.targetObjectTypeId, personTypeId);
    expect(pair.inverseProperty.targetObjectTypeId, bookTypeId);
  });

  test('setting one side updates and removes the inverse side', () async {
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
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: '数論講義',
    );
    final authorA = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: '著者A',
    );
    final authorB = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: '著者B',
    );

    await relations.setRelation(
      objectId: bookId,
      property: pair.sourceProperty,
      targetObjectIds: [authorA, authorB],
    );

    var people = await objectStore.listObjects(personTypeId);
    var a = people.firstWhere((object) => object.id == authorA);
    var b = people.firstWhere((object) => object.id == authorB);
    expect(
      ObjectRelationValue.fromJson(a.values[pair.inverseProperty.id]).objectIds,
      [bookId],
    );
    expect(
      ObjectRelationValue.fromJson(b.values[pair.inverseProperty.id]).objectIds,
      [bookId],
    );

    await relations.setRelation(
      objectId: bookId,
      property: pair.sourceProperty,
      targetObjectIds: [authorB],
    );

    people = await objectStore.listObjects(personTypeId);
    a = people.firstWhere((object) => object.id == authorA);
    b = people.firstWhere((object) => object.id == authorB);
    expect(
      ObjectRelationValue.fromJson(a.values[pair.inverseProperty.id]).objectIds,
      isEmpty,
    );
    expect(
      ObjectRelationValue.fromJson(b.values[pair.inverseProperty.id]).objectIds,
      [bookId],
    );
  });

  test('editing the inverse side also synchronizes the source side', () async {
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
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: '本A',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: '人物A',
    );

    await relations.setRelation(
      objectId: personId,
      property: pair.inverseProperty,
      targetObjectIds: [bookId],
    );

    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[pair.sourceProperty.id]).objectIds,
      [personId],
    );
  });

  test('single-valued inverse rejects conflicting links atomically', () async {
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
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '人物',
    );
    final pair = await relations.createPair(
      sourceObjectTypeId: projectTypeId,
      sourceName: '担当者',
      targetObjectTypeId: personTypeId,
      inverseName: '担当プロジェクト',
      sourceMultiple: false,
      inverseMultiple: false,
    );
    final projectA = await objectStore.createObject(
      objectTypeId: projectTypeId,
      title: 'A',
    );
    final projectB = await objectStore.createObject(
      objectTypeId: projectTypeId,
      title: 'B',
    );
    final person = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: '担当者',
    );

    await relations.setRelation(
      objectId: projectA,
      property: pair.sourceProperty,
      targetObjectIds: [person],
    );
    await expectLater(
      relations.setRelation(
        objectId: projectB,
        property: pair.sourceProperty,
        targetObjectIds: [person],
      ),
      throwsStateError,
    );

    final projects = await objectStore.listObjects(projectTypeId);
    final b = projects.firstWhere((object) => object.id == projectB);
    expect(
      ObjectRelationValue.fromJson(b.values[pair.sourceProperty.id]).objectIds,
      isEmpty,
    );
  });
}
