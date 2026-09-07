import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_index_reconcile_service.dart';
import 'package:bookmark_app/data/relation_index_service.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_stored_value_inspector.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strict inspection preserves legacy valid shapes and flags dropped items', () {
    final legacy = inspectRelationStoredValue({
      'objectIds': <dynamic>[1, '2'],
    });
    expect(legacy.isMalformed, isFalse);
    expect(legacy.rawObjectIds, [1, 2]);

    final malformed = inspectRelationStoredValue(<dynamic>[1, 'not-an-id']);
    expect(malformed.isMalformed, isTrue);
    expect(malformed.rawObjectIds, [1]);
  });

  test('audit and reconcile refuse malformed persisted Relation values', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final integrity = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
    );
    final reconcile = RelationIndexReconcileService(
      integrityService: integrity,
      indexService: RelationIndexService(objectStore),
    );

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Targets',
      targetObjectTypeId: targetTypeId,
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source',
    );
    await genericStore.setValue(
      recordId: sourceId,
      propertyId: propertyId,
      value: <dynamic>[123, 'broken'],
    );

    final report = await integrity.auditWorkspace(workspaceId);
    expect(
      report.issuesOf(RelationIntegrityIssueKind.malformedStoredValue),
      hasLength(1),
    );
    await expectLater(reconcile.reconcileWorkspace(workspaceId), throwsStateError);
    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(source.values[propertyId], <dynamic>[123, 'broken']);
  });

  test('canonical mutation refuses malformed source and inverse values', () async {
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
      title: 'Person',
    );

    await mutations.setRelation(
      objectId: bookId,
      property: pair.sourceProperty,
      targetObjectIds: [personId],
    );
    await genericStore.setValue(
      recordId: personId,
      propertyId: pair.inverseProperty.id,
      value: <dynamic>[bookId, 'broken'],
    );

    await expectLater(
      mutations.setRelation(
        objectId: bookId,
        property: pair.sourceProperty,
        targetObjectIds: const <int>[],
      ),
      throwsStateError,
    );

    final book = (await objectStore.listObjects(bookTypeId)).single;
    final person = (await objectStore.listObjects(personTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[pair.sourceProperty.id]).objectIds,
      [personId],
    );
    expect(
      person.values[pair.inverseProperty.id],
      <dynamic>[bookId, 'broken'],
    );
    expect(
      (await objectStore.outgoingRelations(bookId))
          .where((edge) => edge.propertyId == pair.sourceProperty.id)
          .map((edge) => edge.targetObjectId),
      [personId],
    );
  });
}
