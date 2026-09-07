import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

ObjectGroupBucket<AppObject> _group(int objectId) => ObjectGroupBucket<AppObject>(
      key: '$objectId',
      label: '$objectId',
      value: objectId,
      items: const <AppObject>[],
      isEmptyGroup: false,
    );

void main() {
  test('page Board Relation move preserves bidirectional lifecycle', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final bidirectionalStore = BidirectionalRelationStore(
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
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final aliceId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Alice',
    );
    final bobId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Bob',
    );

    await services.relationMutations.setRelation(
      objectId: bookId,
      property: pair.sourceProperty,
      targetObjectIds: <int>[aliceId],
    );
    final bookBefore = (await objectStore.listObjects(bookTypeId)).single;

    await services.boardMoveService.move(
      object: bookBefore,
      property: pair.sourceProperty,
      sourceGroup: _group(aliceId),
      targetGroup: _group(bobId),
    );

    final bookAfter = (await objectStore.listObjects(bookTypeId)).single;
    final people = await objectStore.listObjects(personTypeId);
    final aliceAfter = people.singleWhere((object) => object.id == aliceId);
    final bobAfter = people.singleWhere((object) => object.id == bobId);

    expect(
      ObjectRelationValue.fromJson(
        bookAfter.values[pair.sourceProperty.id],
      ).objectIds,
      <int>[bobId],
    );
    expect(
      ObjectRelationValue.fromJson(
        aliceAfter.values[pair.inverseProperty.id],
      ).objectIds,
      isEmpty,
    );
    expect(
      ObjectRelationValue.fromJson(
        bobAfter.values[pair.inverseProperty.id],
      ).objectIds,
      <int>[bookId],
    );

    final sourceEdges = (await objectStore.outgoingRelations(bookId))
        .where((edge) => edge.propertyId == pair.sourceProperty.id)
        .toList(growable: false);
    expect(sourceEdges, hasLength(1));
    expect(sourceEdges.single.targetObjectId, bobId);

    final aliceInverseEdges = (await objectStore.outgoingRelations(aliceId))
        .where((edge) => edge.propertyId == pair.inverseProperty.id)
        .toList(growable: false);
    expect(aliceInverseEdges, isEmpty);
    final bobInverseEdges = (await objectStore.outgoingRelations(bobId))
        .where((edge) => edge.propertyId == pair.inverseProperty.id)
        .toList(growable: false);
    expect(bobInverseEdges, hasLength(1));
    expect(bobInverseEdges.single.targetObjectId, bookId);
  });
}
