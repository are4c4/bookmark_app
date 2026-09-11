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
  test('incoming rewire preserves order', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final relation = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'People',
      multiple: true,
    );
    final survivor = await fixture.createObject(personTypeId, 'Survivor');
    final retired = await fixture.createObject(personTypeId, 'Retired');
    final other = await fixture.createObject(personTypeId, 'Other');
    final source = await fixture.createObject(sourceTypeId, 'Source');
    await fixture.objectStore.setRelation(
      objectId: source,
      property: relation,
      targetObjectIds: <int>[other, retired],
    );

    final plan = await fixture.mergeService.preview(
      workspaceId: fixture.workspaceId,
      objectTypeId: personTypeId,
      survivorObjectId: survivor,
      retiredObjectId: retired,
    );

    expect(plan.isExecutable, isTrue);
    expect(plan.changedSurvivingSourceObjectIds, <int>[source]);
    final mutation = plan.mutations.singleWhere(
      (item) => item.sourceObjectId == source && item.propertyId == relation.id,
    );
    expect(mutation.beforeTargetObjectIds, <int>[other, retired]);
    expect(mutation.afterTargetObjectIds, <int>[other, survivor]);

    final impact = await fixture.mergeService.apply(plan);

    expect(impact.changedSurvivingSourceObjectIds, <int>[source]);
    expect(
      await fixture.relationValue(sourceTypeId, source, relation.id),
      <int>[other, survivor],
    );
    expect(await fixture.objectStore.backlinks(retired), isEmpty);
  });

  test('duplicate rewire is blocked', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final relation = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'People',
      multiple: true,
    );
    final survivor = await fixture.createObject(personTypeId, 'Survivor');
    final retired = await fixture.createObject(personTypeId, 'Retired');
    final source = await fixture.createObject(sourceTypeId, 'Source');
    await fixture.objectStore.setRelation(
      objectId: source,
      property: relation,
      targetObjectIds: <int>[survivor, retired],
    );

    final plan = await fixture.mergeService.preview(
      workspaceId: fixture.workspaceId,
      objectTypeId: personTypeId,
      survivorObjectId: survivor,
      retiredObjectId: retired,
    );

    expect(plan.isExecutable, isFalse);
    expect(
      plan.relationBlockers.map((blocker) => blocker.key),
      contains('relation:$source:${relation.id}:duplicate-retarget'),
    );
    await expectLater(fixture.mergeService.apply(plan), throwsStateError);
    expect(
      await fixture.relationValue(sourceTypeId, source, relation.id),
      <int>[survivor, retired],
    );
  });

  test('outgoing conflict is blocked', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final friend = await fixture.createRelation(
      sourceTypeId: personTypeId,
      targetTypeId: personTypeId,
      name: 'Friend',
      multiple: true,
    );
    final survivor = await fixture.createObject(personTypeId, 'Survivor');
    final retired = await fixture.createObject(personTypeId, 'Retired');
    final first = await fixture.createObject(personTypeId, 'First');
    final second = await fixture.createObject(personTypeId, 'Second');
    await fixture.objectStore.setRelation(
      objectId: survivor,
      property: friend,
      targetObjectIds: <int>[first],
    );
    await fixture.objectStore.setRelation(
      objectId: retired,
      property: friend,
      targetObjectIds: <int>[second],
    );

    final plan = await fixture.mergeService.preview(
      workspaceId: fixture.workspaceId,
      objectTypeId: personTypeId,
      survivorObjectId: survivor,
      retiredObjectId: retired,
    );

    expect(plan.isExecutable, isFalse);
    expect(
      plan.relationBlockers.map((blocker) => blocker.key),
      contains('relation:${friend.id}:outgoing-conflict'),
    );
    await expectLater(fixture.mergeService.apply(plan), throwsStateError);
    expect(
      await fixture.relationValue(personTypeId, survivor, friend.id),
      <int>[first],
    );
    expect(await fixture.relationValue(personTypeId, retired, friend.id), <int>[
      second,
    ]);
  });

  test('one-empty outgoing transfers', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final friend = await fixture.createRelation(
      sourceTypeId: personTypeId,
      targetTypeId: personTypeId,
      name: 'Friend',
      multiple: true,
    );
    final survivor = await fixture.createObject(personTypeId, 'Survivor');
    final retired = await fixture.createObject(personTypeId, 'Retired');
    final other = await fixture.createObject(personTypeId, 'Other');
    await fixture.objectStore.setRelation(
      objectId: retired,
      property: friend,
      targetObjectIds: <int>[other],
    );

    final plan = await fixture.mergeService.preview(
      workspaceId: fixture.workspaceId,
      objectTypeId: personTypeId,
      survivorObjectId: survivor,
      retiredObjectId: retired,
    );

    expect(plan.isExecutable, isTrue);
    expect(plan.changedSurvivingSourceObjectIds, <int>[survivor]);
    final impact = await fixture.mergeService.apply(plan);
    expect(impact.changedSurvivingSourceObjectIds, <int>[survivor]);
    expect(
      await fixture.relationValue(personTypeId, survivor, friend.id),
      <int>[other],
    );
    expect(
      await fixture.relationValue(personTypeId, retired, friend.id),
      isEmpty,
    );
    expect(
      (await fixture.objectStore.backlinks(other))
          .map((edge) => edge.sourceObjectId),
      <int>[survivor],
    );
  });

  test('bidirectional rewire stays synchronized', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final bookTypeId = await fixture.createType('Book');
    final pair = await fixture.bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final survivor = await fixture.createObject(personTypeId, 'Survivor');
    final retired = await fixture.createObject(personTypeId, 'Retired');
    final book = await fixture.createObject(bookTypeId, 'Book');
    await fixture.mutationService.setRelation(
      objectId: book,
      property: pair.sourceProperty,
      targetObjectIds: <int>[retired],
    );

    final plan = await fixture.mergeService.preview(
      workspaceId: fixture.workspaceId,
      objectTypeId: personTypeId,
      survivorObjectId: survivor,
      retiredObjectId: retired,
    );

    expect(plan.isExecutable, isTrue);
    expect(plan.changedSurvivingSourceObjectIds, <int>[book, survivor]..sort());
    await fixture.mergeService.apply(plan);

    expect(
      await fixture.relationValue(bookTypeId, book, pair.sourceProperty.id),
      <int>[survivor],
    );
    expect(
      await fixture.relationValue(
        personTypeId,
        survivor,
        pair.inverseProperty.id,
      ),
      <int>[book],
    );
    expect(
      await fixture.relationValue(
        personTypeId,
        retired,
        pair.inverseProperty.id,
      ),
      isEmpty,
    );
  });

  test('index drift blocks merge', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final relation = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'Person',
      multiple: false,
    );
    final survivor = await fixture.createObject(personTypeId, 'Survivor');
    final retired = await fixture.createObject(personTypeId, 'Retired');
    final source = await fixture.createObject(sourceTypeId, 'Source');
    await fixture.objectStore.setRelation(
      objectId: source,
      property: relation,
      targetObjectIds: <int>[retired],
    );
    await fixture.database.customStatement(
      '''DELETE FROM object_relation_edges
         WHERE source_object_id = ? AND property_id = ?''',
      <Object>[source, relation.id],
    );

    final plan = await fixture.mergeService.preview(
      workspaceId: fixture.workspaceId,
      objectTypeId: personTypeId,
      survivorObjectId: survivor,
      retiredObjectId: retired,
    );

    expect(plan.isExecutable, isFalse);
    expect(
      plan.relationBlockers.map((blocker) => blocker.key),
      contains(
        predicate<String>(
          (key) => key.startsWith('relation-integrity:missingIndexEdge:'),
        ),
      ),
    );
    await expectLater(fixture.mergeService.apply(plan), throwsStateError);
    expect(
      await fixture.relationValue(sourceTypeId, source, relation.id),
      <int>[retired],
    );
  });

  test('malformed value blocks merge', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final relation = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'Person',
      multiple: false,
    );
    final survivor = await fixture.createObject(personTypeId, 'Survivor');
    final retired = await fixture.createObject(personTypeId, 'Retired');
    final source = await fixture.createObject(sourceTypeId, 'Source');
    await fixture.objectStore.setRelation(
      objectId: source,
      property: relation,
      targetObjectIds: <int>[retired],
    );
    await fixture.genericStore.setValue(
      recordId: source,
      propertyId: relation.id,
      value: <String, Object>{
        'objectIds': <Object>['not-an-object-id'],
      },
    );

    final plan = await fixture.mergeService.preview(
      workspaceId: fixture.workspaceId,
      objectTypeId: personTypeId,
      survivorObjectId: survivor,
      retiredObjectId: retired,
    );

    expect(plan.isExecutable, isFalse);
    expect(
      plan.relationBlockers.map((blocker) => blocker.key),
      contains(
        predicate<String>(
          (key) => key.startsWith('relation-integrity:malformedStoredValue:'),
        ),
      ),
    );
  });

  test('outer transaction rolls back rewires', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final relation = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'Person',
      multiple: false,
    );
    final survivor = await fixture.createObject(personTypeId, 'Survivor');
    final retired = await fixture.createObject(personTypeId, 'Retired');
    final sourceA = await fixture.createObject(sourceTypeId, 'A');
    final sourceB = await fixture.createObject(sourceTypeId, 'B');
    for (final source in <int>[sourceA, sourceB]) {
      await fixture.objectStore.setRelation(
        objectId: source,
        property: relation,
        targetObjectIds: <int>[retired],
      );
    }
    final plan = await fixture.mergeService.preview(
      workspaceId: fixture.workspaceId,
      objectTypeId: personTypeId,
      survivorObjectId: survivor,
      retiredObjectId: retired,
    );

    await expectLater(
      fixture.database.transaction(() async {
        await fixture.mergeService.apply(plan);
        throw StateError('forced A-owned finalization failure');
      }),
      throwsStateError,
    );

    for (final source in <int>[sourceA, sourceB]) {
      expect(
        await fixture.relationValue(sourceTypeId, source, relation.id),
        <int>[retired],
      );
    }
    expect(await fixture.objectStore.backlinks(survivor), isEmpty);
    expect(
      (await fixture.objectStore.backlinks(retired))
          .map((edge) => edge.sourceObjectId)
          .toSet(),
      <int>{sourceA, sourceB},
    );
  });
}

class _Fixture {
  _Fixture._({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.bidirectionalStore,
    required this.mutationService,
    required this.mergeService,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final BidirectionalRelationStore bidirectionalStore;
  final RelationMutationService mutationService;
  final RelationObjectMergeService mergeService;

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
    return _Fixture._(
      database: database,
      workspaceId: workspaceId,
      genericStore: genericStore,
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      mutationService: mutationService,
      mergeService: RelationObjectMergeService(
        objectStore: objectStore,
        mutationService: mutationService,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
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
