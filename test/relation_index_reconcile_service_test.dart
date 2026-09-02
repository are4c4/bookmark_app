import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_index_reconcile_service.dart';
import 'package:bookmark_app/data/relation_index_service.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RelationIndexReconcileService buildService(
    GenericDatabaseStore genericStore,
    ObjectStore objectStore,
  ) {
    final integrityService = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    return RelationIndexReconcileService(
      integrityService: integrityService,
      indexService: RelationIndexService(objectStore),
    );
  }

  test('reconcile is a no-op for a healthy workspace', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = buildService(genericStore, objectStore);

    final result = await service.reconcileWorkspace(workspaceId);

    expect(result.rebuilt, isFalse);
    expect(result.before.isHealthy, isTrue);
    expect(result.after.isHealthy, isTrue);
  });

  test('reconcile rebuilds a missing index edge without changing Relation value', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = buildService(genericStore, objectStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: property,
      targetObjectIds: [personId],
    );
    await database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      [bookId, property.id],
    );

    final result = await service.reconcileWorkspace(workspaceId);

    expect(result.rebuilt, isTrue);
    expect(
      result.before.issuesOf(RelationIntegrityIssueKind.missingIndexEdge),
      hasLength(1),
    );
    expect(result.after.isHealthy, isTrue);
    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[property.id]).objectIds,
      [personId],
    );
  });

  test('reconcile removes a stale index edge using persisted values as truth', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = buildService(genericStore, objectStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: property,
      targetObjectIds: [personId],
    );
    await genericStore.setValue(
      recordId: bookId,
      propertyId: property.id,
      value: const {'objectIds': []},
    );

    final result = await service.reconcileWorkspace(workspaceId);

    expect(result.rebuilt, isTrue);
    expect(
      result.before.issuesOf(RelationIntegrityIssueKind.staleIndexEdge),
      hasLength(1),
    );
    expect(result.after.isHealthy, isTrue);
    expect(await objectStore.outgoingRelations(bookId), isEmpty);
  });

  test('reconcile refuses ambiguous missing-target data before rebuilding', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = buildService(genericStore, objectStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    await genericStore.setValue(
      recordId: bookId,
      propertyId: property.id,
      value: const {'objectIds': [999999]},
    );

    await expectLater(
      service.reconcileWorkspace(workspaceId),
      throwsStateError,
    );

    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[property.id]).objectIds,
      [999999],
    );
    expect(await objectStore.outgoingRelations(bookId), isEmpty);
  });
}
