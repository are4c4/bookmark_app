import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_index_reconcile_service.dart';
import 'package:bookmark_app/data/relation_index_service.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_stored_value_inspection.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored Relation inspection preserves compatible legacy shapes', () {
    expect(inspectRelationStoredValue(null).isMalformed, isFalse);
    expect(inspectRelationStoredValue(7).rawObjectIds, <int>[7]);
    expect(
      inspectRelationStoredValue(<dynamic>[1, '2']).rawObjectIds,
      <int>[1, 2],
    );
    expect(
      inspectRelationStoredValue(<String, dynamic>{
        'objectIds': <dynamic>['3', 4],
      }).rawObjectIds,
      <int>[3, 4],
    );

    expect(inspectRelationStoredValue('7').isMalformed, isTrue);
    expect(inspectRelationStoredValue(<dynamic>[1, 'broken']).isMalformed, isTrue);
    expect(
      inspectRelationStoredValue(<String, dynamic>{'objectIds': 1}).isMalformed,
      isTrue,
    );
    expect(
      inspectRelationStoredValue(<String, dynamic>{'other': <int>[]}).isMalformed,
      isTrue,
    );
  });

  test(
      'malformed persisted Relation is audited and canonical write/delete preserve it',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );
    final integrity = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
    );
    final reconcile = RelationIndexReconcileService(
      integrityService: integrity,
      indexService: RelationIndexService(objectStore),
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Authors',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final relation = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((property) => property.id == relationId);
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Alice',
    );

    await objectStore.setRelation(
      objectId: bookId,
      property: relation,
      targetObjectIds: <int>[personId],
    );
    await genericStore.setValue(
      recordId: bookId,
      propertyId: relation.id,
      value: <dynamic>[personId, 'broken-id'],
    );

    final report = await integrity.auditWorkspace(workspaceId);
    final malformed = report
        .issuesOf(RelationIntegrityIssueKind.malformedStoredValue)
        .toList();
    expect(malformed, hasLength(1));
    expect(malformed.single.sourceObjectId, bookId);
    expect(malformed.single.propertyId, relation.id);
    expect(report.issuesOf(RelationIntegrityIssueKind.missingIndexEdge), isEmpty);
    expect(report.issuesOf(RelationIntegrityIssueKind.staleIndexEdge), isEmpty);

    await expectLater(reconcile.reconcileWorkspace(workspaceId), throwsStateError);
    await expectLater(
      mutations.setRelation(
        objectId: bookId,
        property: relation,
        targetObjectIds: const <int>[],
      ),
      throwsStateError,
    );
    await expectLater(
      mutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: personTypeId,
        objectId: personId,
      ),
      throwsStateError,
    );

    final storedBook = (await objectStore.listObjects(bookTypeId)).single;
    expect(storedBook.values[relation.id], <dynamic>[personId, 'broken-id']);
    final people = await objectStore.listObjects(personTypeId);
    expect(people.map((person) => person.id), contains(personId));
    final edges = await objectStore.outgoingRelations(bookId);
    expect(edges, hasLength(1));
    expect(edges.single.propertyId, relation.id);
    expect(edges.single.targetObjectId, personId);
  });

  test('malformed inverse Relation rolls back bidirectional mutation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
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
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Alice',
    );

    await mutations.setRelation(
      objectId: bookId,
      property: pair.sourceProperty,
      targetObjectIds: <int>[personId],
    );
    await genericStore.setValue(
      recordId: personId,
      propertyId: pair.inverseProperty.id,
      value: <dynamic>[bookId, 'broken-id'],
    );

    await expectLater(
      mutations.setRelation(
        objectId: bookId,
        property: pair.sourceProperty,
        targetObjectIds: const <int>[],
      ),
      throwsStateError,
    );

    final storedBook = (await objectStore.listObjects(bookTypeId)).single;
    final storedPerson = (await objectStore.listObjects(personTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(
        storedBook.values[pair.sourceProperty.id],
      ).objectIds,
      <int>[personId],
    );
    expect(
      storedPerson.values[pair.inverseProperty.id],
      <dynamic>[bookId, 'broken-id'],
    );

    final sourceEdges = await objectStore.outgoingRelations(bookId);
    expect(sourceEdges, hasLength(1));
    expect(sourceEdges.single.targetObjectId, personId);
    final inverseEdges = await objectStore.outgoingRelations(personId);
    expect(inverseEdges, hasLength(1));
    expect(inverseEdges.single.targetObjectId, bookId);
  });
}
