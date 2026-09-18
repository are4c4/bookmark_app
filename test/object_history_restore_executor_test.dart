import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_history_checkpoint_loader.dart';
import 'package:bookmark_app/data/object_history_relation_service.dart';
import 'package:bookmark_app/data/object_history_restore_executor.dart';
import 'package:bookmark_app/data/object_history_restore_preparation_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_history_checkpoint.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:bookmark_app/domain/object_history_relation.dart';
import 'package:bookmark_app/domain/object_history_restore_planner.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'whole restore atomically restores A fields plus one and many Relations',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final personTypeId = await fixture.createType('Person');
      final sourceTypeId = await fixture.createType('Source');
      final note = await fixture.createValueProperty(sourceTypeId, 'Note');
      final primary = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'Primary',
        multiple: false,
      );
      final people = await fixture.createRelation(
        sourceTypeId: sourceTypeId,
        targetTypeId: personTypeId,
        name: 'People',
        multiple: true,
      );
      final historicalPrimary = await fixture.createObject(
        personTypeId,
        'Historical primary',
      );
      final currentPrimary = await fixture.createObject(
        personTypeId,
        'Current primary',
      );
      final historicalFirst = await fixture.createObject(
        personTypeId,
        'Historical first',
      );
      final historicalSecond = await fixture.createObject(
        personTypeId,
        'Historical second',
      );
      final currentPerson = await fixture.createObject(
        personTypeId,
        'Current person',
      );
      final source = await fixture.createObject(sourceTypeId, 'Current title');

      await fixture.mutationService.setRelation(
        objectId: source,
        property: primary,
        targetObjectIds: <int>[historicalPrimary],
      );
      await fixture.mutationService.setRelation(
        objectId: source,
        property: people,
        targetObjectIds: <int>[historicalFirst, historicalSecond],
      );
      final historicalPrimarySnapshot = await fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: source,
        propertyId: primary.id,
      );
      final historicalPeopleSnapshot = await fixture.historyService.capture(
        workspaceId: fixture.workspaceId,
        sourceObjectId: source,
        propertyId: people.id,
      );

      await fixture.mutationService.setRelation(
        objectId: source,
        property: primary,
        targetObjectIds: <int>[currentPrimary],
      );
      await fixture.mutationService.setRelation(
        objectId: source,
        property: people,
        targetObjectIds: <int>[currentPerson],
      );
      await fixture.genericStore.setValue(
        recordId: source,
        propertyId: note.id,
        value: 'current note',
      );
      await fixture.bodyStore.write(
        objectId: source,
        document: _body('current body'),
      );

      final historical = _checkpoint(
        objectId: source,
        revisionId: 2,
        title: 'Historical title',
        valueProperty: note,
        value: 'historical note',
        body: _body('historical body'),
        relations: <ObjectPropertyDefinition>[primary, people],
      );
      final current = _checkpoint(
        objectId: source,
        revisionId: 3,
        title: 'Current title',
        valueProperty: note,
        value: 'current note',
        body: _body('current body'),
        relations: <ObjectPropertyDefinition>[primary, people],
      );
      final relationPlans = <ObjectHistoryRelationRestorePlan>[
        await fixture.historyService.previewRestore(
          workspaceId: fixture.workspaceId,
          historical: historicalPrimarySnapshot,
        ),
        await fixture.historyService.previewRestore(
          workspaceId: fixture.workspaceId,
          historical: historicalPeopleSnapshot,
        ),
      ];
      final preparation = _preparation(
        historical: historical,
        current: current,
        scope: ObjectHistoryRestoreScope.wholeObject(),
        relationSnapshots: <ObjectHistoryRelationSnapshot>[
          historicalPrimarySnapshot,
          historicalPeopleSnapshot,
        ],
        relationPlans: relationPlans,
      );
      final executor = ObjectHistoryRestoreExecutor.fromServices(
        genericStore: fixture.genericStore,
        loadCurrent: () async => current,
        relationService: fixture.historyService,
      );

      final impact = await executor.execute(
        preparation: preparation,
        expectedCurrentRevisionId: 3,
      );

      final restored = await fixture.object(sourceTypeId, source);
      expect(restored.title, 'Historical title');
      expect(restored.values[note.id], 'historical note');
      expect(
        (await fixture.bodyStore.read(source)).toJson(),
        _body('historical body').toJson(),
      );
      expect(
        await fixture.relationValue(sourceTypeId, source, primary.id),
        <int>[historicalPrimary],
      );
      expect(
        await fixture.relationValue(sourceTypeId, source, people.id),
        <int>[historicalFirst, historicalSecond],
      );
      expect(impact.objectId, source);
      expect(impact.changedObjectIds, contains(source));
    },
  );

  test('selective restore mutates only requested A fields', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final sourceTypeId = await fixture.createType('Source');
    final note = await fixture.createValueProperty(sourceTypeId, 'Note');
    final source = await fixture.createObject(sourceTypeId, 'Current title');
    await fixture.genericStore.setValue(
      recordId: source,
      propertyId: note.id,
      value: 'current note',
    );
    await fixture.bodyStore.write(
      objectId: source,
      document: _body('current body'),
    );

    final historical = _checkpoint(
      objectId: source,
      revisionId: 2,
      title: 'Historical title',
      valueProperty: note,
      value: 'historical note',
      body: _body('historical body'),
    );
    final current = _checkpoint(
      objectId: source,
      revisionId: 3,
      title: 'Current title',
      valueProperty: note,
      value: 'current note',
      body: _body('current body'),
    );
    final preparation = _preparation(
      historical: historical,
      current: current,
      scope: ObjectHistoryRestoreScope.selective(
        <ObjectHistoryFieldTarget>[ObjectHistoryFieldTarget.title()],
      ),
    );
    final executor = ObjectHistoryRestoreExecutor(
      genericStore: fixture.genericStore,
      loadCurrent: () async => current,
      applyRelationRestore: (_) async =>
          ObjectHistoryRelationRestoreImpact(changedObjectIds: const <int>[]),
    );

    await executor.execute(
      preparation: preparation,
      expectedCurrentRevisionId: 3,
    );

    final restored = await fixture.object(sourceTypeId, source);
    expect(restored.title, 'Historical title');
    expect(restored.values[note.id], 'current note');
    expect(
      (await fixture.bodyStore.read(source)).toJson(),
      _body('current body').toJson(),
    );
  });

  test('stale current revision rejects before any mutation', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final sourceTypeId = await fixture.createType('Source');
    final source = await fixture.createObject(sourceTypeId, 'Current title');
    final historical = _checkpoint(
      objectId: source,
      revisionId: 2,
      title: 'Historical title',
      body: _body('historical body'),
    );
    final preparedCurrent = _checkpoint(
      objectId: source,
      revisionId: 3,
      title: 'Current title',
      body: const ObjectBodyDocument(),
    );
    final actualCurrent = _checkpoint(
      objectId: source,
      revisionId: 4,
      title: 'Current title',
      body: const ObjectBodyDocument(),
    );
    final preparation = _preparation(
      historical: historical,
      current: preparedCurrent,
      scope: ObjectHistoryRestoreScope.wholeObject(),
    );
    var relationCalls = 0;
    final executor = ObjectHistoryRestoreExecutor(
      genericStore: fixture.genericStore,
      loadCurrent: () async => actualCurrent,
      applyRelationRestore: (_) async {
        relationCalls += 1;
        return ObjectHistoryRelationRestoreImpact(
          changedObjectIds: const <int>[],
        );
      },
    );

    await expectLater(
      executor.execute(
        preparation: preparation,
        expectedCurrentRevisionId: 3,
      ),
      throwsStateError,
    );

    expect((await fixture.object(sourceTypeId, source)).title, 'Current title');
    expect(await fixture.bodyStore.read(source), isA<ObjectBodyDocument>());
    expect(relationCalls, 0);
  });

  test('late Relation failure rolls back prior A and B mutations', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final note = await fixture.createValueProperty(sourceTypeId, 'Note');
    final person = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'Person',
      multiple: false,
    );
    final historicalTarget = await fixture.createObject(
      personTypeId,
      'Historical target',
    );
    final currentTarget = await fixture.createObject(
      personTypeId,
      'Current target',
    );
    final source = await fixture.createObject(sourceTypeId, 'Current title');

    await fixture.mutationService.setRelation(
      objectId: source,
      property: person,
      targetObjectIds: <int>[historicalTarget],
    );
    final historicalRelation = await fixture.historyService.capture(
      workspaceId: fixture.workspaceId,
      sourceObjectId: source,
      propertyId: person.id,
    );
    await fixture.mutationService.setRelation(
      objectId: source,
      property: person,
      targetObjectIds: <int>[currentTarget],
    );
    await fixture.genericStore.setValue(
      recordId: source,
      propertyId: note.id,
      value: 'current note',
    );
    await fixture.bodyStore.write(
      objectId: source,
      document: _body('current body'),
    );

    final historical = _checkpoint(
      objectId: source,
      revisionId: 2,
      title: 'Historical title',
      valueProperty: note,
      value: 'historical note',
      body: _body('historical body'),
      relations: <ObjectPropertyDefinition>[person],
    );
    final current = _checkpoint(
      objectId: source,
      revisionId: 3,
      title: 'Current title',
      valueProperty: note,
      value: 'current note',
      body: _body('current body'),
      relations: <ObjectPropertyDefinition>[person],
    );
    final relationPlan = await fixture.historyService.previewRestore(
      workspaceId: fixture.workspaceId,
      historical: historicalRelation,
    );
    final preparation = _preparation(
      historical: historical,
      current: current,
      scope: ObjectHistoryRestoreScope.wholeObject(),
      relationSnapshots: <ObjectHistoryRelationSnapshot>[historicalRelation],
      relationPlans: <ObjectHistoryRelationRestorePlan>[relationPlan],
    );
    final executor = ObjectHistoryRestoreExecutor(
      genericStore: fixture.genericStore,
      loadCurrent: () async => current,
      applyRelationRestore: (plan) async {
        await fixture.historyService.applyRestore(plan);
        throw StateError('forced late Relation failure');
      },
    );

    await expectLater(
      executor.execute(
        preparation: preparation,
        expectedCurrentRevisionId: 3,
      ),
      throwsStateError,
    );

    final preserved = await fixture.object(sourceTypeId, source);
    expect(preserved.title, 'Current title');
    expect(preserved.values[note.id], 'current note');
    expect(
      (await fixture.bodyStore.read(source)).toJson(),
      _body('current body').toJson(),
    );
    expect(
      await fixture.relationValue(sourceTypeId, source, person.id),
      <int>[currentTarget],
    );
  });

  test('late A failure leaves Relation state untouched', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final personTypeId = await fixture.createType('Person');
    final sourceTypeId = await fixture.createType('Source');
    final note = await fixture.createValueProperty(sourceTypeId, 'Note');
    final person = await fixture.createRelation(
      sourceTypeId: sourceTypeId,
      targetTypeId: personTypeId,
      name: 'Person',
      multiple: false,
    );
    final historicalTarget = await fixture.createObject(
      personTypeId,
      'Historical target',
    );
    final currentTarget = await fixture.createObject(
      personTypeId,
      'Current target',
    );
    final source = await fixture.createObject(sourceTypeId, 'Current title');

    await fixture.mutationService.setRelation(
      objectId: source,
      property: person,
      targetObjectIds: <int>[historicalTarget],
    );
    final historicalRelation = await fixture.historyService.capture(
      workspaceId: fixture.workspaceId,
      sourceObjectId: source,
      propertyId: person.id,
    );
    await fixture.mutationService.setRelation(
      objectId: source,
      property: person,
      targetObjectIds: <int>[currentTarget],
    );
    await fixture.genericStore.setValue(
      recordId: source,
      propertyId: note.id,
      value: 'current note',
    );
    await fixture.bodyStore.write(
      objectId: source,
      document: _body('current body'),
    );

    final historical = _checkpoint(
      objectId: source,
      revisionId: 2,
      title: 'Historical title',
      valueProperty: note,
      value: 'historical note',
      body: _body('historical body'),
      relations: <ObjectPropertyDefinition>[person],
    );
    final current = _checkpoint(
      objectId: source,
      revisionId: 3,
      title: 'Current title',
      valueProperty: note,
      value: 'current note',
      body: _body('current body'),
      relations: <ObjectPropertyDefinition>[person],
    );
    final relationPlan = await fixture.historyService.previewRestore(
      workspaceId: fixture.workspaceId,
      historical: historicalRelation,
    );
    final preparation = _preparation(
      historical: historical,
      current: current,
      scope: ObjectHistoryRestoreScope.wholeObject(),
      relationSnapshots: <ObjectHistoryRelationSnapshot>[historicalRelation],
      relationPlans: <ObjectHistoryRelationRestorePlan>[relationPlan],
    );
    var relationCalls = 0;
    final executor = ObjectHistoryRestoreExecutor(
      genericStore: fixture.genericStore,
      loadCurrent: () async => current,
      bodyStore: _RejectingBodyStore(fixture.genericStore),
      applyRelationRestore: (plan) async {
        relationCalls += 1;
        return fixture.historyService.applyRestore(plan);
      },
    );

    await expectLater(
      executor.execute(
        preparation: preparation,
        expectedCurrentRevisionId: 3,
      ),
      throwsStateError,
    );

    final preserved = await fixture.object(sourceTypeId, source);
    expect(preserved.title, 'Current title');
    expect(preserved.values[note.id], 'current note');
    expect(
      (await fixture.bodyStore.read(source)).toJson(),
      _body('current body').toJson(),
    );
    expect(
      await fixture.relationValue(sourceTypeId, source, person.id),
      <int>[currentTarget],
    );
    expect(relationCalls, 0);
  });
}

ObjectHistoryRestorePreparation _preparation({
  required ObjectHistoryCheckpointPayload historical,
  required ObjectHistoryCheckpointPayload current,
  required ObjectHistoryRestoreScope scope,
  List<ObjectHistoryRelationSnapshot> relationSnapshots =
      const <ObjectHistoryRelationSnapshot>[],
  List<ObjectHistoryRelationRestorePlan> relationPlans =
      const <ObjectHistoryRelationRestorePlan>[],
}) {
  final preview = const ObjectHistoryCheckpointRestorePlanner().preview(
    historical: historical,
    current: current,
    scope: scope,
  );
  return ObjectHistoryRestorePreparation(
    historical: ObjectHistoryWholeCheckpoint(
      checkpoint: historical,
      relationSnapshots: relationSnapshots,
    ),
    preview: preview,
    relationPlans: relationPlans,
  );
}

ObjectHistoryCheckpointPayload _checkpoint({
  required int objectId,
  required int revisionId,
  required String title,
  required ObjectBodyDocument body,
  ObjectPropertyDefinition? valueProperty,
  dynamic value,
  List<ObjectPropertyDefinition> relations =
      const <ObjectPropertyDefinition>[],
}) => ObjectHistoryCheckpointPayload(
  entry: ObjectHistoryEntry(
    objectId: objectId,
    revisionId: revisionId,
    previousRevisionId: revisionId > 1 ? revisionId - 1 : null,
    capturedAt: DateTime.utc(2026, 9, 18, revisionId),
    source: ObjectHistorySourceKind.userMutation,
  ),
  title: title,
  propertySnapshots: <ObjectHistoryPropertySnapshot>[
    if (valueProperty != null)
      ObjectHistoryPropertySnapshot.fromDefinition(
        property: valueProperty,
        value: value,
      ),
  ],
  body: body,
  relationRequirements: <ObjectHistoryRelationRequirement>[
    for (final relation in relations)
      ObjectHistoryRelationRequirement.fromDefinition(relation),
  ],
);

ObjectBodyDocument _body(String text) => ObjectBodyDocument(
  blocks: <ObjectBodyBlock>[
    ObjectBodyBlock.paragraph(id: 'paragraph', text: text),
  ],
);

class _RejectingBodyStore extends ObjectBodyStore {
  _RejectingBodyStore(super.genericStore);

  @override
  Future<bool> writeIfUnchanged({
    required int objectId,
    required ObjectBodyDocument expected,
    required ObjectBodyDocument document,
  }) async => false;
}

class _Fixture {
  _Fixture._({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.bodyStore,
    required this.bidirectionalStore,
    required this.mutationService,
    required this.historyService,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final ObjectBodyStore bodyStore;
  final BidirectionalRelationStore bidirectionalStore;
  final RelationMutationService mutationService;
  final ObjectHistoryRelationService historyService;

  static Future<_Fixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
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
      bodyStore: bodyStore,
      bidirectionalStore: bidirectionalStore,
      mutationService: mutationService,
      historyService: historyService,
    );
  }

  Future<int> createType(String name) =>
      objectStore.createObjectType(workspaceId: workspaceId, name: name);

  Future<int> createObject(int objectTypeId, String title) =>
      objectStore.createObject(objectTypeId: objectTypeId, title: title);

  Future<ObjectPropertyDefinition> createValueProperty(
    int objectTypeId,
    String name,
  ) async {
    final propertyId = await objectStore.createProperty(
      objectTypeId: objectTypeId,
      name: name,
      type: ObjectPropertyType.text,
    );
    return (await objectStore.getObjectType(objectTypeId))!.properties
        .singleWhere((property) => property.id == propertyId);
  }

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

  Future<AppObject> object(int objectTypeId, int objectId) async =>
      (await objectStore.listObjects(objectTypeId)).singleWhere(
        (candidate) => candidate.id == objectId,
      );

  Future<List<int>> relationValue(
    int objectTypeId,
    int objectId,
    int propertyId,
  ) async {
    final current = await object(objectTypeId, objectId);
    return ObjectRelationValue.fromJson(current.values[propertyId]).objectIds;
  }
}
