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
  test(
    'audit and reconcile remove index edges that do not belong to source Relation Properties',
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

      final sourceTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Source',
      );
      final otherSourceTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Other source',
      );
      final targetTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Target',
      );
      final textPropertyId = await objectStore.createProperty(
        objectTypeId: sourceTypeId,
        name: 'Notes',
        type: ObjectPropertyType.text,
      );
      final foreignRelationPropertyId = await objectStore.createRelationProperty(
        objectTypeId: otherSourceTypeId,
        name: 'Target',
        targetObjectTypeId: targetTypeId,
      );
      final sourceObjectId = await objectStore.createObject(
        objectTypeId: sourceTypeId,
        title: 'Source object',
      );
      final targetObjectId = await objectStore.createObject(
        objectTypeId: targetTypeId,
        title: 'Target object',
      );

      await objectStore.outgoingRelations(sourceObjectId);
      await database.customStatement(
        '''INSERT INTO object_relation_edges(
             source_object_id, property_id, target_object_id, position
           ) VALUES (?, ?, ?, ?)''',
        [sourceObjectId, textPropertyId, targetObjectId, 0],
      );
      await database.customStatement(
        '''INSERT INTO object_relation_edges(
             source_object_id, property_id, target_object_id, position
           ) VALUES (?, ?, ?, ?)''',
        [sourceObjectId, foreignRelationPropertyId, targetObjectId, 0],
      );

      final before = await integrity.auditWorkspace(workspaceId);
      final stale = before
          .issuesOf(RelationIntegrityIssueKind.staleIndexEdge)
          .toList(growable: false);
      expect(stale, hasLength(2));
      expect(
        stale.map((issue) => issue.propertyId).toSet(),
        {textPropertyId, foreignRelationPropertyId},
      );
      expect(
        before.issues.where(
          (issue) => issue.kind != RelationIntegrityIssueKind.staleIndexEdge,
        ),
        isEmpty,
      );

      final result = await reconcile.reconcileWorkspace(workspaceId);

      expect(result.rebuilt, isTrue);
      expect(result.after.isHealthy, isTrue);
      expect(await objectStore.outgoingRelations(sourceObjectId), isEmpty);
      final sourceObject = (await objectStore.listObjects(sourceTypeId)).single;
      expect(sourceObject.values, isEmpty);
      expect(
        (await objectStore.getObjectType(sourceTypeId))!
            .properties
            .singleWhere((property) => property.id == textPropertyId)
            .type,
        ObjectPropertyType.text,
      );
      expect(
        (await objectStore.getObjectType(otherSourceTypeId))!
            .properties
            .singleWhere((property) => property.id == foreignRelationPropertyId)
            .isRelation,
        isTrue,
      );
    },
  );
}
