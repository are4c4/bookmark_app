import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_merge_finalizer.dart';
import 'package:bookmark_app/data/object_merge_state_store.dart';
import 'package:bookmark_app/data/object_redirect_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_object_merge_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_merge_contract.dart';
import 'package:bookmark_app/domain/object_merge_state_materializer.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'finalizes Relation rewire, A state, redirect and retirement atomically',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final sourceTypeId = await fixture.createType('Source');
      final personRelation = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'Person',
        multiple: false,
      );
      final survivor = await fixture.createObject(personTypeId, 'Survivor');
      final retired = await fixture.createObject(personTypeId, 'Retired');
      final source = await fixture.createObject(sourceTypeId, 'Source');
      await fixture.mutationService.setRelation(
        objectId: source,
        property: personRelation,
        targetObjectIds: <int>[retired],
      );

      final prepared = await fixture.prepare(
        objectTypeId: personTypeId,
        survivorObjectId: survivor,
        retiredObjectId: retired,
      );
      final plan = prepared.plan(
        decisions: <String, ObjectMergeDecision>{
          'title': ObjectMergeDecision.takeRetired,
        },
      );

      final result = await fixture.finalizer.finalize(
        workspaceId: fixture.workspaceId,
        prepared: prepared,
        plan: plan,
      );

      expect(result.alreadyFinalized, isFalse);
      expect(result.survivingObjectId, survivor);
      expect(result.relationImpact!.changedSurvivingSourceObjectIds, <int>[
        source,
      ]);
      expect(
        await fixture.relationValue(sourceTypeId, source, personRelation.id),
        <int>[survivor],
      );
      expect(
        (await fixture.objectStore.listObjects(personTypeId))
            .map((object) => object.id),
        <int>[survivor],
      );
      expect(
        (await fixture.objectStore.listObjects(personTypeId)).single.title,
        'Retired',
      );
      expect(await fixture.redirectStore.resolve(retired), survivor);

      final retry = await fixture.finalizer.finalize(
        workspaceId: fixture.workspaceId,
        prepared: prepared,
        plan: plan,
      );
      expect(retry.alreadyFinalized, isTrue);
      expect(retry.survivingObjectId, survivor);
      expect(retry.relationImpact, isNull);
    },
  );

  test('stale retired A state fails before Relation mutation', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final personRelation = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'Person',
      multiple: false,
    );
    final survivor = await fixture.createObject(personTypeId, 'Same');
    final retired = await fixture.createObject(personTypeId, 'Same');
    final source = await fixture.createObject(sourceTypeId, 'Source');
    await fixture.mutationService.setRelation(
      objectId: source,
      property: personRelation,
      targetObjectIds: <int>[retired],
    );

    final prepared = await fixture.prepare(
      objectTypeId: personTypeId,
      survivorObjectId: survivor,
      retiredObjectId: retired,
    );
    final plan = prepared.plan();
    await fixture.objectStore.renameObject(retired, 'Concurrent edit');

    await expectLater(
      fixture.finalizer.finalize(
        workspaceId: fixture.workspaceId,
        prepared: prepared,
        plan: plan,
      ),
      throwsStateError,
    );

    expect(
      await fixture.relationValue(sourceTypeId, source, personRelation.id),
      <int>[retired],
    );
    expect(await fixture.redirectStore.resolve(retired), retired);
    expect(
      (await fixture.objectStore.listObjects(personTypeId))
          .map((object) => object.id)
          .toSet(),
      <int>{survivor, retired},
    );
  });

  test(
    'fresh Relation blocker fails before A persistence or retirement',
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
        targetObjectIds: <int>[retired],
      );

      final prepared = await fixture.prepare(
        objectTypeId: personTypeId,
        survivorObjectId: survivor,
        retiredObjectId: retired,
      );
      final plan = prepared.plan();

      await fixture.mutationService.setRelation(
        objectId: source,
        property: peopleRelation,
        targetObjectIds: <int>[survivor, retired],
      );

      await expectLater(
        fixture.finalizer.finalize(
          workspaceId: fixture.workspaceId,
          prepared: prepared,
          plan: plan,
        ),
        throwsStateError,
      );

      expect(
        await fixture.relationValue(sourceTypeId, source, peopleRelation.id),
        <int>[survivor, retired],
      );
      expect(await fixture.redirectStore.resolve(retired), retired);
      expect(
        (await fixture.objectStore.listObjects(personTypeId))
            .map((object) => object.id)
            .toSet(),
        <int>{survivor, retired},
      );
    },
  );

  test(
    'late retired-row delete failure rolls back every merge mutation',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final sourceTypeId = await fixture.createType('Source');
      final personRelation = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'Person',
        multiple: false,
      );
      final survivor = await fixture.createObject(personTypeId, 'Survivor');
      final retired = await fixture.createObject(personTypeId, 'Retired');
      final source = await fixture.createObject(sourceTypeId, 'Source');
      await fixture.mutationService.setRelation(
        objectId: source,
        property: personRelation,
        targetObjectIds: <int>[retired],
      );

      final prepared = await fixture.prepare(
        objectTypeId: personTypeId,
        survivorObjectId: survivor,
        retiredObjectId: retired,
      );
      final plan = prepared.plan(
        decisions: <String, ObjectMergeDecision>{
          'title': ObjectMergeDecision.takeRetired,
        },
      );

      await fixture.database.customStatement('''
        CREATE TRIGGER fail_object_merge_retirement
        BEFORE DELETE ON generic_records
        WHEN OLD.id = $retired
        BEGIN
          SELECT RAISE(ABORT, 'forced retirement failure');
        END
      ''');

      await expectLater(
        fixture.finalizer.finalize(
          workspaceId: fixture.workspaceId,
          prepared: prepared,
          plan: plan,
        ),
        throwsA(anything),
      );

      expect(
        await fixture.relationValue(sourceTypeId, source, personRelation.id),
        <int>[retired],
      );
      expect(
        (await fixture.objectStore.listObjects(personTypeId))
            .singleWhere((object) => object.id == survivor)
            .title,
        'Survivor',
      );
      expect(await fixture.redirectStore.resolve(retired), retired);
      expect(
        (await fixture.objectStore.listObjects(personTypeId))
            .map((object) => object.id)
            .toSet(),
        <int>{survivor, retired},
      );
    },
  );
}

class _Fixture {
  _Fixture._({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.mutationService,
    required this.stateStore,
    required this.redirectStore,
    required this.finalizer,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final RelationMutationService mutationService;
  final ObjectMergeStateStore stateStore;
  final ObjectRedirectStore redirectStore;
  final ObjectMergeFinalizer finalizer;

  static Future<_Fixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
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
    final relationMergeService = RelationObjectMergeService(
      objectStore: objectStore,
      mutationService: mutationService,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );
    final stateStore = ObjectMergeStateStore(genericStore);
    final redirectStore = ObjectRedirectStore(genericStore);

    return _Fixture._(
      database: database,
      workspaceId: workspaceId,
      genericStore: genericStore,
      objectStore: objectStore,
      mutationService: mutationService,
      stateStore: stateStore,
      redirectStore: redirectStore,
      finalizer: ObjectMergeFinalizer(
        genericStore: genericStore,
        stateStore: stateStore,
        relationMergeService: relationMergeService,
        redirectStore: redirectStore,
        objectStore: objectStore,
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

  Future<ObjectMergePreparedState> prepare({
    required int objectTypeId,
    required int survivorObjectId,
    required int retiredObjectId,
  }) async => ObjectMergePreparedState.prepare(
    survivor: await stateStore.capture(
      objectTypeId: objectTypeId,
      objectId: survivorObjectId,
    ),
    retired: await stateStore.capture(
      objectTypeId: objectTypeId,
      objectId: retiredObjectId,
    ),
  );

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
