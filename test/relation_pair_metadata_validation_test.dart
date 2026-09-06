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
  test('pairFor requires complementary source and inverse pair roles', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: sourceTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: targetTypeId,
      inverseName: 'Books',
    );

    expect(await bidirectionalStore.pairFor(pair.sourceProperty), isNotNull);
    expect(await bidirectionalStore.pairFor(pair.inverseProperty), isNotNull);

    final inverse = (await genericStore.listProperties(targetTypeId))
        .singleWhere((property) => property.id == pair.inverseProperty.id);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: inverse.id,
        databaseId: inverse.databaseId,
        name: inverse.name,
        type: inverse.type,
        sortOrder: inverse.sortOrder,
        config: <String, dynamic>{...inverse.config, 'pairRole': 'source'},
      ),
    );

    final refreshedSource = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == pair.sourceProperty.id);
    expect(await bidirectionalStore.pairFor(refreshedSource), isNull);

    final report = await RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
    ).auditWorkspace(workspaceId);
    expect(
      report
          .issuesOf(RelationIntegrityIssueKind.invalidBidirectionalPair)
          .map((issue) => issue.propertyId),
      contains(pair.sourceProperty.id),
    );
  });

  test('reserved pair key presence fails closed across Relation entrypoints',
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
    final schemaEvolution = RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
      relationMutations: mutations,
    );
    final deleteInspection = DatabaseViewPropertySchemaService(
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

    final stored = (await genericStore.listProperties(sourceTypeId))
        .singleWhere((property) => property.id == relationId);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: stored.id,
        databaseId: stored.databaseId,
        name: stored.name,
        type: stored.type,
        sortOrder: stored.sortOrder,
        config: <String, dynamic>{...stored.config, 'pairRole': null},
      ),
    );
    final relation = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == relationId);

    expect(bidirectionalStore.hasManagedPairMetadata(relation), isTrue);
    expect(await bidirectionalStore.pairFor(relation), isNull);

    final report = await RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
    ).auditWorkspace(workspaceId);
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
      deleteInspection.inspectDelete(
        objectTypeId: sourceTypeId,
        propertyId: relationId,
      ),
      throwsStateError,
    );
    await expectLater(
      schemaEvolution.inspectChange(
        property: relation,
        targetObjectTypeId: targetTypeId,
        multiple: true,
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
