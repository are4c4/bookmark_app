import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_history_relation_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_history_relation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'capture preserves exact ordered Relation evidence and round-trips',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final sourceTypeId = await fixture.createType('Source');
      final people = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'People',
        multiple: true,
      );
      final first = await fixture.createObject(personTypeId, 'First');
      final second = await fixture.createObject(personTypeId, 'Second');
      final source = await fixture.createObject(sourceTypeId, 'Source');
      await fixture.mutationService.setRelation(
        objectId: source,
        property: people,
        targetObjectIds: <int>[second, first],
      );

      final snapshot = await fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: source,
        propertyId: people.id,
      );

      expect(snapshot.sourceObjectId, source);
      expect(snapshot.sourceObjectTypeId, sourceTypeId);
      expect(snapshot.targetObjectTypeId, personTypeId);
      expect(snapshot.allowsMultipleRelations, isTrue);
      expect(snapshot.targetObjectIds, <int>[second, first]);
      expect(
        snapshot.ordering,
        ObjectHistoryRelationOrdering.explicitTargetOrder,
      );
      expect(snapshot.isBidirectional, isFalse);

      final json = snapshot.toJson();
      final restored = ObjectHistoryRelationSnapshot.fromJson(json);
      expect(restored.targetObjectIds, <int>[second, first]);
      expect(restored.propertyId, people.id);
      (json['targetObjectIds'] as List<int>).clear();
      expect(snapshot.targetObjectIds, <int>[second, first]);
      expect(() => snapshot.targetObjectIds.add(first), throwsUnsupportedError);
    },
  );

  test('capture preserves canonical bidirectional role metadata', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final bookTypeId = await fixture.createType('Book');
    final personTypeId = await fixture.createType('Person');
    final pair = await fixture.bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: personTypeId,
      inverseName: 'Primary book',
      sourceMultiple: true,
      inverseMultiple: false,
    );
    final book = await fixture.createObject(bookTypeId, 'Book');
    final person = await fixture.createObject(personTypeId, 'Person');
    await fixture.mutationService.setRelation(
      objectId: book,
      property: pair.sourceProperty,
      targetObjectIds: <int>[person],
    );

    final snapshot = await fixture.historyService.capture(
      workspaceId: fixture.workspaceId,
      sourceObjectId: book,
      propertyId: pair.sourceProperty.id,
    );

    expect(snapshot.isBidirectional, isTrue);
    expect(snapshot.inversePropertyId, pair.inverseProperty.id);
    expect(snapshot.pairRole, ObjectHistoryRelationPairRole.source);
    expect(snapshot.inverseAllowsMultipleRelations, isFalse);
  });

  test('capture fails closed on serialized/index drift', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final person = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'Person',
      multiple: false,
    );
    final target = await fixture.createObject(personTypeId, 'Target');
    final source = await fixture.createObject(sourceTypeId, 'Source');
    await fixture.mutationService.setRelation(
      objectId: source,
      property: person,
      targetObjectIds: <int>[target],
    );
    await fixture.database.customStatement(
      '''DELETE FROM object_relation_edges
         WHERE source_object_id = ? AND property_id = ?''',
      <Object>[source, person.id],
    );

    await expectLater(
      fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: source,
        propertyId: person.id,
      ),
      throwsStateError,
    );
  });

  test(
    'retired target requires explicit resolution without rewriting history',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final sourceTypeId = await fixture.createType('Source');
      final person = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'Person',
        multiple: false,
      );
      final retired = await fixture.createObject(personTypeId, 'Retired');
      final source = await fixture.createObject(sourceTypeId, 'Source');
      await fixture.mutationService.setRelation(
        objectId: source,
        property: person,
        targetObjectIds: <int>[retired],
      );
      final historical = await fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: source,
        propertyId: person.id,
      );

      await fixture.mutationService.setRelation(
        objectId: source,
        property: person,
        targetObjectIds: const <int>[],
      );
      await fixture.objectStore.deleteObject(retired);
      final survivor = await fixture.createObject(personTypeId, 'Survivor');

      final blocked = await fixture.historyService.previewRestore(
        workspaceId: fixture.workspaceId,
        historical: historical,
      );
      expect(blocked.isExecutable, isFalse);
      expect(
        blocked.blockers.map((blocker) => blocker.key),
        contains('target:$retired:resolution-required'),
      );

      final plan = await fixture.historyService.previewRestore(
        workspaceId: fixture.workspaceId,
        historical: historical,
        targetResolutions: <int, int>{retired: survivor},
      );
      expect(plan.isExecutable, isTrue);
      expect(plan.afterTargetObjectIds, <int>[survivor]);
      expect(plan.targetResolutions.single.wasRedirected, isTrue);
      expect(historical.targetObjectIds, <int>[retired]);

      await fixture.historyService.applyRestore(plan);
      expect(
        await fixture.relationValue(sourceTypeId, source, person.id),
        <int>[survivor],
      );
    },
  );

  test(
    'redirect convergence to duplicate current target remains blocked',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final sourceTypeId = await fixture.createType('Source');
      final people = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'People',
        multiple: true,
      );
      final firstRetired = await fixture.createObject(
        personTypeId,
        'First old',
      );
      final secondRetired = await fixture.createObject(
        personTypeId,
        'Second old',
      );
      final source = await fixture.createObject(sourceTypeId, 'Source');
      await fixture.mutationService.setRelation(
        objectId: source,
        property: people,
        targetObjectIds: <int>[firstRetired, secondRetired],
      );
      final historical = await fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: source,
        propertyId: people.id,
      );
      await fixture.mutationService.setRelation(
        objectId: source,
        property: people,
        targetObjectIds: const <int>[],
      );
      await fixture.objectStore.deleteObject(firstRetired);
      await fixture.objectStore.deleteObject(secondRetired);
      final survivor = await fixture.createObject(personTypeId, 'Survivor');

      final plan = await fixture.historyService.previewRestore(
        workspaceId: fixture.workspaceId,
        historical: historical,
        targetResolutions: <int, int>{
          firstRetired: survivor,
          secondRetired: survivor,
        },
      );

      expect(plan.isExecutable, isFalse);
      expect(
        plan.blockers.map((blocker) => blocker.key),
        contains('property:${people.id}:duplicate-resolution'),
      );
      await expectLater(
        fixture.historyService.applyRestore(plan),
        throwsStateError,
      );
      expect(
        await fixture.relationValue(sourceTypeId, source, people.id),
        isEmpty,
      );
    },
  );

  test('current Relation schema drift blocks historical replay', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final person = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'Person',
      multiple: false,
    );
    final source = await fixture.createObject(sourceTypeId, 'Source');
    final target = await fixture.createObject(personTypeId, 'Target');
    final historical = ObjectHistoryRelationSnapshot(
      sourceObjectId: source,
      sourceObjectTypeId: sourceTypeId,
      propertyId: person.id,
      targetObjectTypeId: personTypeId,
      allowsMultipleRelations: true,
      targetObjectIds: <int>[target],
    );

    final plan = await fixture.historyService.previewRestore(
      workspaceId: fixture.workspaceId,
      historical: historical,
    );

    expect(plan.isExecutable, isFalse);
    expect(
      plan.blockers.map((blocker) => blocker.key),
      contains('property:${person.id}:cardinality-changed'),
    );
  });

  test(
    'single inverse Relation conflict makes restore non-executable',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final bookTypeId = await fixture.createType('Book');
      final personTypeId = await fixture.createType('Person');
      final pair = await fixture.bidirectionalStore.createPair(
        sourceObjectTypeId: bookTypeId,
        sourceName: 'Author',
        targetObjectTypeId: personTypeId,
        inverseName: 'Primary book',
        sourceMultiple: false,
        inverseMultiple: false,
      );
      final firstBook = await fixture.createObject(bookTypeId, 'First book');
      final secondBook = await fixture.createObject(bookTypeId, 'Second book');
      final person = await fixture.createObject(personTypeId, 'Person');
      await fixture.mutationService.setRelation(
        objectId: firstBook,
        property: pair.sourceProperty,
        targetObjectIds: <int>[person],
      );
      final historical = await fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: firstBook,
        propertyId: pair.sourceProperty.id,
      );
      await fixture.mutationService.setRelation(
        objectId: firstBook,
        property: pair.sourceProperty,
        targetObjectIds: const <int>[],
      );
      await fixture.mutationService.setRelation(
        objectId: secondBook,
        property: pair.sourceProperty,
        targetObjectIds: <int>[person],
      );

      final plan = await fixture.historyService.previewRestore(
        workspaceId: fixture.workspaceId,
        historical: historical,
      );

      expect(plan.isExecutable, isFalse);
      expect(
        plan.blockers.map((blocker) => blocker.key),
        contains('target:$person:inverse-cardinality-conflict'),
      );
    },
  );

  test(
    'successful bidirectional restore keeps pair and index synchronized',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final bookTypeId = await fixture.createType('Book');
      final personTypeId = await fixture.createType('Person');
      final pair = await fixture.bidirectionalStore.createPair(
        sourceObjectTypeId: bookTypeId,
        sourceName: 'Authors',
        targetObjectTypeId: personTypeId,
        inverseName: 'Books',
      );
      final book = await fixture.createObject(bookTypeId, 'Book');
      final firstPerson = await fixture.createObject(personTypeId, 'First');
      final secondPerson = await fixture.createObject(personTypeId, 'Second');
      await fixture.mutationService.setRelation(
        objectId: book,
        property: pair.sourceProperty,
        targetObjectIds: <int>[firstPerson],
      );
      final historical = await fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: book,
        propertyId: pair.sourceProperty.id,
      );
      await fixture.mutationService.setRelation(
        objectId: book,
        property: pair.sourceProperty,
        targetObjectIds: <int>[secondPerson],
      );

      final plan = await fixture.historyService.previewRestore(
        workspaceId: fixture.workspaceId,
        historical: historical,
      );
      expect(plan.isExecutable, isTrue);
      expect(
        plan.changedObjectIds,
        <int>[book, firstPerson, secondPerson]..sort(),
      );

      final impact = await fixture.historyService.applyRestore(plan);
      expect(impact.changedObjectIds, plan.changedObjectIds);
      expect(
        await fixture.relationValue(bookTypeId, book, pair.sourceProperty.id),
        <int>[firstPerson],
      );
      expect(
        await fixture.relationValue(
          personTypeId,
          firstPerson,
          pair.inverseProperty.id,
        ),
        <int>[book],
      );
      expect(
        await fixture.relationValue(
          personTypeId,
          secondPerson,
          pair.inverseProperty.id,
        ),
        isEmpty,
      );
      final report = await RelationIntegrityService(
        objectStore: fixture.objectStore,
        bidirectionalStore: fixture.bidirectionalStore,
      ).auditWorkspace(fixture.workspaceId);
      expect(report.isHealthy, isTrue);
    },
  );

  test(
    'apply rejects stale plan without overwriting a newer Relation edit',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final sourceTypeId = await fixture.createType('Source');
      final person = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'Person',
        multiple: false,
      );
      final historicalTarget = await fixture.createObject(personTypeId, 'Old');
      final currentTarget = await fixture.createObject(personTypeId, 'Current');
      final newerTarget = await fixture.createObject(personTypeId, 'Newer');
      final source = await fixture.createObject(sourceTypeId, 'Source');
      await fixture.mutationService.setRelation(
        objectId: source,
        property: person,
        targetObjectIds: <int>[historicalTarget],
      );
      final historical = await fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: source,
        propertyId: person.id,
      );
      await fixture.mutationService.setRelation(
        objectId: source,
        property: person,
        targetObjectIds: <int>[currentTarget],
      );
      final stalePlan = await fixture.historyService.previewRestore(
        workspaceId: fixture.workspaceId,
        historical: historical,
      );
      expect(stalePlan.isExecutable, isTrue);

      await fixture.mutationService.setRelation(
        objectId: source,
        property: person,
        targetObjectIds: <int>[newerTarget],
      );
      await expectLater(
        fixture.historyService.applyRestore(stalePlan),
        throwsStateError,
      );
      expect(
        await fixture.relationValue(sourceTypeId, source, person.id),
        <int>[newerTarget],
      );
    },
  );

  test(
    'outer restore transaction rollback restores all Relation mutations',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final sourceTypeId = await fixture.createType('Source');
      final person = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'Person',
        multiple: false,
      );
      final historicalTarget = await fixture.createObject(personTypeId, 'Old');
      final currentTarget = await fixture.createObject(personTypeId, 'Current');
      final source = await fixture.createObject(sourceTypeId, 'Source');
      await fixture.mutationService.setRelation(
        objectId: source,
        property: person,
        targetObjectIds: <int>[historicalTarget],
      );
      final historical = await fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: source,
        propertyId: person.id,
      );
      await fixture.mutationService.setRelation(
        objectId: source,
        property: person,
        targetObjectIds: <int>[currentTarget],
      );
      final plan = await fixture.historyService.previewRestore(
        workspaceId: fixture.workspaceId,
        historical: historical,
      );

      await expectLater(
        fixture.database.transaction(() async {
          await fixture.historyService.applyRestore(plan);
          throw StateError('forced A-owned later restore failure');
        }),
        throwsStateError,
      );
      expect(
        await fixture.relationValue(sourceTypeId, source, person.id),
        <int>[currentTarget],
      );
      expect(
        (await fixture.objectStore.backlinks(historicalTarget)).isEmpty,
        isTrue,
      );
      expect(
        (await fixture.objectStore.backlinks(currentTarget))
            .map((edge) => edge.sourceObjectId),
        <int>[source],
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
    required this.bidirectionalStore,
    required this.mutationService,
    required this.historyService,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final BidirectionalRelationStore bidirectionalStore;
  final RelationMutationService mutationService;
  final ObjectHistoryRelationService historyService;

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
    final historyService = ObjectHistoryRelationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      mutationService: mutationService,
      genericStore: genericStore,
    );
    return _Fixture._(
      database: database,
      workspaceId: workspaceId,
      genericStore: genericStore,
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      mutationService: mutationService,
      historyService: historyService,
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
