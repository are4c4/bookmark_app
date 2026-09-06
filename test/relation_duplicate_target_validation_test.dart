import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Relation mutation rejects duplicate targets before writes',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
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
      name: 'Targets',
      targetObjectTypeId: targetTypeId,
      multiple: true,
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source object',
    );
    final firstTargetId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'First target',
    );
    final secondTargetId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Second target',
    );
    final relation = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == relationId);

    await mutations.setRelation(
      objectId: sourceId,
      property: relation,
      targetObjectIds: [firstTargetId, secondTargetId],
    );

    await expectLater(
      mutations.setRelation(
        objectId: sourceId,
        property: relation,
        targetObjectIds: [firstTargetId, firstTargetId],
      ),
      throwsArgumentError,
    );

    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(source.values[relationId], [firstTargetId, secondTargetId]);
    final edges = await objectStore.outgoingRelations(sourceId);
    expect(edges, hasLength(2));
    expect(
      edges.map((edge) => edge.targetObjectId).toList(),
      [firstTargetId, secondTargetId],
    );
  });
}
