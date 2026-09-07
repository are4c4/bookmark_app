import 'dart:convert';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_index_reconcile_service.dart';
import 'package:bookmark_app/data/relation_index_service.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate persisted multi-Relation target is audited and not reconciled',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final integrity = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
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

    // Establish a normalized edge first, then simulate legacy/corrupt persisted
    // JSON with the same target repeated. The semantic Relation value normally
    // de-duplicates this shape, while integrity audit must retain enough raw
    // persisted information to diagnose it.
    await objectStore.setRelation(
      objectId: bookId,
      property: relation,
      targetObjectIds: [personId],
    );
    await genericStore.setValue(
      recordId: bookId,
      propertyId: relation.id,
      value: {
        'objectIds': [personId, personId],
      },
    );

    final report = await integrity.auditWorkspace(workspaceId);
    final duplicates = report
        .issuesOf(RelationIntegrityIssueKind.duplicateTargetObject)
        .toList();
    expect(duplicates, hasLength(1));
    expect(duplicates.single.sourceObjectId, bookId);
    expect(duplicates.single.propertyId, relation.id);
    expect(duplicates.single.targetObjectId, personId);
    expect(report.issuesOf(RelationIntegrityIssueKind.missingIndexEdge), isEmpty);
    expect(report.issuesOf(RelationIntegrityIssueKind.staleIndexEdge), isEmpty);

    await expectLater(
      reconcile.reconcileWorkspace(workspaceId),
      throwsStateError,
    );

    final rawRow = await database.customSelect(
      '''SELECT value_json
         FROM generic_values
         WHERE record_id = ? AND property_id = ?''',
      variables: [Variable<int>(bookId), Variable<int>(relation.id)],
    ).getSingle();
    final rawValue = jsonDecode(rawRow.read<String>('value_json')) as Map;
    expect(rawValue['objectIds'], [personId, personId]);

    final edges = await objectStore.outgoingRelations(bookId);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, personId);
  });
}
