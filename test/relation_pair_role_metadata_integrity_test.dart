import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_schema_evolution_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pairRole-only metadata fails closed across canonical Relation boundaries',
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
    final schemaEvolution = RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
      relationMutations: mutations,
    );
    final propertySchema = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: DatabaseViewStore(database),
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
    await expectLater(
      bidirectionalStore.setRelation(
        objectId: sourceId,
        property: relation,
        targetObjectIds: <int>[targetId],
      ),
      throwsStateError,
    );
    await expectLater(
      schemaEvolution.inspectChange(
        property: relation,
        targetObjectTypeId: targetTypeId,
        multiple: false,
      ),
      throwsStateError,
    );
    await expectLater(
      propertySchema.inspectDelete(
        objectTypeId: sourceTypeId,
        propertyId: relationId,
      ),
      throwsStateError,
    );

    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(source.values[relationId]).objectIds,
      isEmpty,
    );
    expect(await objectStore.backlinks(targetId), isEmpty);

    final unchangedRelation = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == relationId);
    expect(unchangedRelation.targetObjectTypeId, targetTypeId);
    expect(unchangedRelation.allowsMultipleRelations, isFalse);
    expect(unchangedRelation.config['pairRole'], 'source');
  });
}
