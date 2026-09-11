import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_object_merge_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'apply rejects a stale plan without overwriting a newer Relation edit',
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
      final mutationService = RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      );
      final mergeService = RelationObjectMergeService(
        objectStore: objectStore,
        mutationService: mutationService,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      );

      final personTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Person',
      );
      final sourceTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Source',
      );
      final relationId = await objectStore.createRelationProperty(
        objectTypeId: sourceTypeId,
        name: 'Person',
        targetObjectTypeId: personTypeId,
        multiple: false,
      );
      final relation = (await objectStore.getObjectType(sourceTypeId))!
          .properties
          .singleWhere((property) => property.id == relationId);
      final survivor = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'Survivor',
      );
      final retired = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'Retired',
      );
      final newerTarget = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'Newer target',
      );
      final source = await objectStore.createObject(
        objectTypeId: sourceTypeId,
        title: 'Source',
      );
      await mutationService.setRelation(
        objectId: source,
        property: relation,
        targetObjectIds: <int>[retired],
      );

      final stalePlan = await mergeService.preview(
        workspaceId: workspaceId,
        objectTypeId: personTypeId,
        survivorObjectId: survivor,
        retiredObjectId: retired,
      );
      expect(stalePlan.isExecutable, isTrue);

      await mutationService.setRelation(
        objectId: source,
        property: relation,
        targetObjectIds: <int>[newerTarget],
      );

      await expectLater(mergeService.apply(stalePlan), throwsStateError);

      final persistedSource = (await objectStore.listObjects(sourceTypeId))
          .singleWhere((object) => object.id == source);
      expect(
        ObjectRelationValue.fromJson(persistedSource.values[relation.id])
            .objectIds,
        <int>[newerTarget],
      );
      expect(await objectStore.backlinks(survivor), isEmpty);
      expect(await objectStore.backlinks(retired), isEmpty);
    },
  );
}
