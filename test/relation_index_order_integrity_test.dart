import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_index_reconcile_service.dart';
import 'package:bookmark_app/data/relation_index_service.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reconcile restores Relation edge order without rewriting persisted value',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final integrityService = RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
      );
      final reconcileService = RelationIndexReconcileService(
        integrityService: integrityService,
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
      await objectStore.createRelationProperty(
        objectTypeId: sourceTypeId,
        name: 'Targets',
        targetObjectTypeId: targetTypeId,
        multiple: true,
      );
      final property =
          (await objectStore.getObjectType(sourceTypeId))!.properties.single;
      final sourceId = await objectStore.createObject(
        objectTypeId: sourceTypeId,
        title: 'Source',
      );
      final firstTargetId = await objectStore.createObject(
        objectTypeId: targetTypeId,
        title: 'First',
      );
      final secondTargetId = await objectStore.createObject(
        objectTypeId: targetTypeId,
        title: 'Second',
      );
      await objectStore.setRelation(
        objectId: sourceId,
        property: property,
        targetObjectIds: [firstTargetId, secondTargetId],
      );
      final rawValueBefore =
          (await objectStore.listObjects(sourceTypeId)).single.values[property.id];

      await database.customStatement(
        '''UPDATE object_relation_edges
           SET position = CASE target_object_id
             WHEN ? THEN 1
             WHEN ? THEN 0
             ELSE position
           END
           WHERE source_object_id = ? AND property_id = ?''',
        [firstTargetId, secondTargetId, sourceId, property.id],
      );

      final audit = await integrityService.auditWorkspace(workspaceId);
      expect(
        audit.issuesOf(RelationIntegrityIssueKind.indexOrderMismatch),
        hasLength(1),
      );
      expect(
        audit.issuesOf(RelationIntegrityIssueKind.missingIndexEdge),
        isEmpty,
      );
      expect(
        audit.issuesOf(RelationIntegrityIssueKind.staleIndexEdge),
        isEmpty,
      );

      final result = await reconcileService.reconcileWorkspace(workspaceId);

      expect(result.rebuilt, isTrue);
      expect(result.after.isHealthy, isTrue);
      final rawValueAfter =
          (await objectStore.listObjects(sourceTypeId)).single.values[property.id];
      expect(rawValueAfter, equals(rawValueBefore));
      final edges = await objectStore.outgoingRelations(sourceId);
      expect(
        edges.map((edge) => edge.targetObjectId),
        [firstTargetId, secondTargetId],
      );
      expect(edges.map((edge) => edge.position), [0, 1]);
    },
  );
}
