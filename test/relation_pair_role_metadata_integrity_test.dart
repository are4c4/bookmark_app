import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pairRole-only metadata is audited and blocks canonical Relation writes',
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

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Related',
      targetObjectTypeId: targetTypeId,
      multiple: false,
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source',
    );
    final targetId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Target',
    );

    // Simulate historical/corrupt schema that retained only one managed pair
    // key. Canonical Relation Property creation reserves this key and can never
    // create this state.
    final stored = (await genericStore.listProperties(sourceTypeId))
        .singleWhere((property) => property.id == relationId);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: stored.id,
        databaseId: stored.databaseId,
        name: stored.name,
        type: stored.type,
        config: <String, dynamic>{...stored.config, 'pairRole': 'source'},
        sortOrder: stored.sortOrder,
      ),
    );
    final relation = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == relationId);

    final report = await integrity.auditWorkspace(workspaceId);
    expect(
      report
          .issuesOf(RelationIntegrityIssueKind.invalidBidirectionalPair)
          .map((issue) => issue.propertyId),
      contains(relationId),
    );

    await expectLater(
      mutations.setRelation(
        objectId: sourceId,
        property: relation,
        targetObjectIds: <int>[targetId],
      ),
      throwsStateError,
    );

    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(source.values[relationId]).objectIds,
      isEmpty,
    );
    expect(await objectStore.backlinks(targetId), isEmpty);
  });
}
