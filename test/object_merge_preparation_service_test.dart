import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_merge_preparation_service.dart';
import 'package:bookmark_app/data/object_merge_state_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_object_merge_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'prepares one clean merge through canonical A and B boundaries',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final survivor = await fixture.createObject(personTypeId, 'Same');
      final retired = await fixture.createObject(personTypeId, 'Same');

      final preparation = await fixture.preparationService.prepare(
        workspaceId: fixture.workspaceId,
        objectTypeId: personTypeId,
        survivorObjectId: survivor,
        retiredObjectId: retired,
      );

      expect(preparation.prepared.survivor.objectId, survivor);
      expect(preparation.prepared.retired.objectId, retired);
      expect(preparation.relationPlan.survivorObjectId, survivor);
      expect(preparation.relationPlan.retiredObjectId, retired);
      expect(preparation.relationPlan.isExecutable, isTrue);
      expect(preparation.prepared.preview.hasRelationBlockers, isFalse);
      expect(preparation.prepared.plan().isExecutable, isTrue);

      expect(
        (await fixture.objectStore.listObjects(personTypeId))
            .map((object) => object.id)
            .toSet(),
        <int>{survivor, retired},
      );
    },
  );

  test(
    'preserves canonical Relation blockers in the prepared A preview',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final sourceTypeId = await fixture.createType('Source');
      final peopleRelation = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'People',
        multiple: true,
      );
      final survivor = await fixture.createObject(personTypeId, 'Same');
      final retired = await fixture.createObject(personTypeId, 'Same');
      final source = await fixture.createObject(sourceTypeId, 'Source');
      await fixture.mutationService.setRelation(
        objectId: source,
        property: peopleRelation,
        targetObjectIds: <int>[survivor, retired],
      );

      final preparation = await fixture.preparationService.prepare(
        workspaceId: fixture.workspaceId,
        objectTypeId: personTypeId,
        survivorObjectId: survivor,
        retiredObjectId: retired,
      );

      expect(preparation.relationPlan.isExecutable, isFalse);
      expect(preparation.relationPlan.relationBlockers, isNotEmpty);
      expect(preparation.prepared.preview.hasRelationBlockers, isTrue);
      expect(preparation.prepared.plan().isExecutable, isFalse);
      expect(
        preparation.prepared.preview.relationBlockers
            .map((blocker) => blocker.key)
            .toList(),
        preparation.relationPlan.relationBlockers
            .map((blocker) => blocker.key)
            .toList(),
      );
      expect(
        preparation.prepared.preview.relationBlockers
            .map((blocker) => blocker.reason)
            .toList(),
        preparation.relationPlan.relationBlockers
            .map((blocker) => blocker.reason)
            .toList(),
      );
      expect(
        await fixture.relationValue(sourceTypeId, source, peopleRelation.id),
        <int>[survivor, retired],
      );
    },
  );

  test('wrong workspace fails closed without changing either Object', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final survivor = await fixture.createObject(personTypeId, 'Same');
    final retired = await fixture.createObject(personTypeId, 'Same');
    final otherWorkspaceId = await fixture.workspaces.createWorkspace('Other');

    await expectLater(
      fixture.preparationService.prepare(
        workspaceId: otherWorkspaceId,
        objectTypeId: personTypeId,
        survivorObjectId: survivor,
        retiredObjectId: retired,
      ),
      throwsArgumentError,
    );

    expect(
      (await fixture.objectStore.listObjects(personTypeId))
          .map((object) => object.id)
          .toSet(),
      <int>{survivor, retired},
    );
  });

  test(
    'wrong-type or missing retired identity fails before mutation',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final otherTypeId = await fixture.createType('Other');
      final survivor = await fixture.createObject(personTypeId, 'Same');
      final wrongTypeRetired = await fixture.createObject(otherTypeId, 'Same');

      await expectLater(
        fixture.preparationService.prepare(
          workspaceId: fixture.workspaceId,
          objectTypeId: personTypeId,
          survivorObjectId: survivor,
          retiredObjectId: wrongTypeRetired,
        ),
        throwsArgumentError,
      );
      await expectLater(
        fixture.preparationService.prepare(
          workspaceId: fixture.workspaceId,
          objectTypeId: personTypeId,
          survivorObjectId: survivor,
          retiredObjectId: 999999,
        ),
        throwsArgumentError,
      );

      expect(
        (await fixture.objectStore.listObjects(personTypeId)).single.id,
        survivor,
      );
      expect(
        (await fixture.objectStore.listObjects(otherTypeId)).single.id,
        wrongTypeRetired,
      );
    },
  );

  test(
    'unchanged repeated preparation is deterministic and read-only',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final survivor = await fixture.createObject(personTypeId, 'Survivor');
      final retired = await fixture.createObject(personTypeId, 'Retired');

      final first = await fixture.preparationService.prepare(
        workspaceId: fixture.workspaceId,
        objectTypeId: personTypeId,
        survivorObjectId: survivor,
        retiredObjectId: retired,
      );
      final second = await fixture.preparationService.prepare(
        workspaceId: fixture.workspaceId,
        objectTypeId: personTypeId,
        survivorObjectId: survivor,
        retiredObjectId: retired,
      );

      expect(
        second.prepared.preview.requirements.map((item) => item.key).toList(),
        first.prepared.preview.requirements.map((item) => item.key).toList(),
      );
      expect(
        second.prepared.preview.requirements
            .map((item) => item.status)
            .toList(),
        first.prepared.preview.requirements.map((item) => item.status).toList(),
      );
      expect(
        second.relationPlan.relationBlockers
            .map((blocker) => blocker.key)
            .toList(),
        first.relationPlan.relationBlockers
            .map((blocker) => blocker.key)
            .toList(),
      );
      expect(
        (await fixture.objectStore.listObjects(personTypeId))
            .map((object) => object.title)
            .toList(),
        <String>['Survivor', 'Retired'],
      );
    },
  );
}

class _Fixture {
  _Fixture._({
    required this.database,
    required this.workspaceId,
    required this.workspaces,
    required this.objectStore,
    required this.mutationService,
    required this.preparationService,
  });

  final AppDatabase database;
  final int workspaceId;
  final WorkspaceStore workspaces;
  final ObjectStore objectStore;
  final RelationMutationService mutationService;
  final ObjectMergePreparationService preparationService;

  static Future<_Fixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaces = WorkspaceStore(database);
    final workspaceId = await workspaces.initialize();
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
    final relationMergeService = RelationObjectMergeService(
      objectStore: objectStore,
      mutationService: mutationService,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );

    return _Fixture._(
      database: database,
      workspaceId: workspaceId,
      workspaces: workspaces,
      objectStore: objectStore,
      mutationService: mutationService,
      preparationService: ObjectMergePreparationService(
        stateStore: ObjectMergeStateStore(genericStore),
        relationMergeService: relationMergeService,
      ),
    );
  }

  Future<int> createType(String name) =>
      objectStore.createObjectType(workspaceId: workspaceId, name: name);

  Future<int> createObject(int objectTypeId, String title) =>
      objectStore.createObject(objectTypeId: objectTypeId, title: title);

  Future<ObjectPropertyDefinition> createRelation({
    required int sourceTypeId,
    required int targetTypeId,
    required String name,
    required bool multiple,
  }) async {
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: name,
      targetObjectTypeId: targetTypeId,
      multiple: multiple,
    );
    return (await objectStore.getObjectType(sourceTypeId))!.properties
        .singleWhere((property) => property.id == propertyId);
  }

  Future<List<int>> relationValue(
    int objectTypeId,
    int objectId,
    int propertyId,
  ) async {
    final object = (await objectStore.listObjects(objectTypeId))
        .singleWhere((candidate) => candidate.id == objectId);
    return ObjectRelationValue.fromJson(object.values[propertyId]).objectIds;
  }
}
