import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit detects an index edge missing from the persisted Relation value', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );

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

    // Simulate legacy/corrupt state by changing the persisted value without
    // synchronizing the normalized edge index.
    await genericStore.setValue(
      recordId: bookId,
      propertyId: property.id,
      value: const {'objectIds': []},
    );

    final report = await service.auditWorkspace(workspaceId);
    final stale = report.issuesOf(RelationIntegrityIssueKind.staleIndexEdge).toList();
    expect(stale, hasLength(1));
    expect(stale.single.sourceObjectId, bookId);
    expect(stale.single.targetObjectId, personId);
    expect(stale.single.propertyId, property.id);
  });
}
