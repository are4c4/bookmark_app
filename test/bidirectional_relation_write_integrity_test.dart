import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bidirectional write ignores forged caller target metadata', () async {
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
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final placeTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Place',
    );
    final pair = await relations.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final placeId = await objectStore.createObject(
      objectTypeId: placeTypeId,
      title: 'Place',
    );
    final forged = ObjectPropertyDefinition(
      id: pair.sourceProperty.id,
      objectTypeId: pair.sourceProperty.objectTypeId,
      name: pair.sourceProperty.name,
      type: pair.sourceProperty.type,
      sortOrder: pair.sourceProperty.sortOrder,
      config: <String, dynamic>{
        ...pair.sourceProperty.config,
        'targetObjectTypeId': placeTypeId,
      },
    );

    await expectLater(
      relations.setRelation(
        objectId: bookId,
        property: forged,
        targetObjectIds: [placeId],
      ),
      throwsArgumentError,
    );
    expect(await objectStore.outgoingRelations(bookId), isEmpty);
  });

  test('bidirectional write fails closed when persisted pair metadata is broken', () async {
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
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final pair = await relations.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );

    final inverse = (await genericStore.listProperties(personTypeId))
        .singleWhere((property) => property.id == pair.inverseProperty.id);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: inverse.id,
        databaseId: inverse.databaseId,
        name: inverse.name,
        type: inverse.type,
        sortOrder: inverse.sortOrder,
        config: <String, dynamic>{...inverse.config, 'bidirectional': false},
      ),
    );

    await expectLater(
      relations.setRelation(
        objectId: bookId,
        property: pair.sourceProperty,
        targetObjectIds: [personId],
      ),
      throwsStateError,
    );
    expect(await objectStore.outgoingRelations(bookId), isEmpty);
    final person = (await objectStore.listObjects(personTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(person.values[pair.inverseProperty.id]).objectIds,
      isEmpty,
    );
  });
}
