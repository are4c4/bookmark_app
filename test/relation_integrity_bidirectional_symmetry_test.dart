import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit catches an inverse-only bidirectional reference', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
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

    // Bypass the bidirectional facade to simulate legacy/corrupt state where
    // only the inverse side persisted the relationship.
    await objectStore.setRelation(
      objectId: personId,
      property: pair.inverseProperty,
      targetObjectIds: [bookId],
    );

    final report = await service.auditWorkspace(workspaceId);
    final mismatches = report
        .issuesOf(RelationIntegrityIssueKind.inverseValueMismatch)
        .toList();
    expect(mismatches, hasLength(1));
    expect(mismatches.single.sourceObjectId, personId);
    expect(mismatches.single.targetObjectId, bookId);
    expect(mismatches.single.propertyId, pair.inverseProperty.id);
  });
}
