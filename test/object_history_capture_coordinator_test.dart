import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_history_capture_coordinator.dart';
import 'package:bookmark_app/data/object_history_checkpoint_store.dart';
import 'package:bookmark_app/data/object_history_relation_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_history_checkpoint.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:bookmark_app/domain/object_history_relation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('whole-Object capture persists A and B evidence idempotently', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final coordinator = ObjectHistoryCaptureCoordinator(genericStore);
    final checkpointStore = ObjectHistoryCheckpointStore(genericStore);
    final relationStore = ObjectHistoryRelationStore(genericStore);
    final checkpoint = _checkpoint(revisionId: 1, relationPropertyIds: <int>[21, 22]);
    final relations = <ObjectHistoryRelationSnapshot>[
      _relation(propertyId: 21, targetObjectIds: <int>[12, 11]),
      _relation(
        propertyId: 22,
        targetObjectIds: <int>[15],
        allowsMultipleRelations: false,
      ),
    ];

    expect(
      await coordinator.append(
        checkpoint: checkpoint,
        relationSnapshots: relations,
      ),
      isTrue,
    );
    expect(
      await coordinator.append(
        checkpoint: checkpoint,
        relationSnapshots: relations,
      ),
      isFalse,
    );

    expect(
      (await checkpointStore.load(objectId: 7, revisionId: 1))?.title,
      'Title 1',
    );
    final storedRelations = await relationStore.listForRevision(
      sourceObjectId: 7,
      revisionId: 1,
    );
    expect(storedRelations.map((item) => item.propertyId), <int>[21, 22]);
    expect(storedRelations.first.targetObjectIds, <int>[12, 11]);
    expect(storedRelations.last.targetObjectIds, <int>[15]);
  });

  test('Relation evidence shape mismatches fail before persistence', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final coordinator = ObjectHistoryCaptureCoordinator(genericStore);
    final checkpointStore = ObjectHistoryCheckpointStore(genericStore);
    final relationStore = ObjectHistoryRelationStore(genericStore);
    final checkpoint = _checkpoint(revisionId: 1, relationPropertyIds: <int>[21, 22]);

    await expectLater(
      coordinator.append(
        checkpoint: checkpoint,
        relationSnapshots: <ObjectHistoryRelationSnapshot>[
          _relation(propertyId: 21),
        ],
      ),
      throwsArgumentError,
    );
    await expectLater(
      coordinator.append(
        checkpoint: checkpoint,
        relationSnapshots: <ObjectHistoryRelationSnapshot>[
          _relation(propertyId: 21),
          _relation(propertyId: 22),
          _relation(propertyId: 23),
        ],
      ),
      throwsArgumentError,
    );
    await expectLater(
      coordinator.append(
        checkpoint: checkpoint,
        relationSnapshots: <ObjectHistoryRelationSnapshot>[
          _relation(propertyId: 21),
          _relation(propertyId: 21),
        ],
      ),
      throwsArgumentError,
    );
    await expectLater(
      coordinator.append(
        checkpoint: checkpoint,
        relationSnapshots: <ObjectHistoryRelationSnapshot>[
          _relation(propertyId: 21),
          _relation(sourceObjectId: 8, propertyId: 22),
        ],
      ),
      throwsArgumentError,
    );

    expect(await checkpointStore.list(7), isEmpty);
    expect(
      await relationStore.listForRevision(sourceObjectId: 7, revisionId: 1),
      isEmpty,
    );
  });

  test('B history conflict rolls back a newly appended A checkpoint', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final coordinator = ObjectHistoryCaptureCoordinator(genericStore);
    final checkpointStore = ObjectHistoryCheckpointStore(genericStore);
    final relationStore = ObjectHistoryRelationStore(genericStore);

    await relationStore.append(
      revisionId: 1,
      snapshot: _relation(propertyId: 21, targetObjectIds: <int>[99]),
    );

    await expectLater(
      coordinator.append(
        checkpoint: _checkpoint(revisionId: 1),
        relationSnapshots: <ObjectHistoryRelationSnapshot>[
          _relation(propertyId: 21, targetObjectIds: <int>[12]),
        ],
      ),
      throwsStateError,
    );

    expect(
      await checkpointStore.load(objectId: 7, revisionId: 1),
      isNull,
    );
    expect(
      (await relationStore.load(
        sourceObjectId: 7,
        revisionId: 1,
        propertyId: 21,
      ))?.targetObjectIds,
      <int>[99],
    );
  });

  test('caller-owned rollback removes both stores and readiness recovers', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final coordinator = ObjectHistoryCaptureCoordinator(genericStore);
    final checkpointStore = ObjectHistoryCheckpointStore(genericStore);
    final relationStore = ObjectHistoryRelationStore(genericStore);
    final checkpoint = _checkpoint(revisionId: 1);
    final relations = <ObjectHistoryRelationSnapshot>[
      _relation(propertyId: 21),
    ];

    await expectLater(
      database.transaction(() async {
        await coordinator.append(
          checkpoint: checkpoint,
          relationSnapshots: relations,
        );
        throw StateError('force rollback');
      }),
      throwsStateError,
    );

    expect(await checkpointStore.load(objectId: 7, revisionId: 1), isNull);
    expect(
      await relationStore.listForRevision(sourceObjectId: 7, revisionId: 1),
      isEmpty,
    );

    expect(
      await coordinator.append(
        checkpoint: checkpoint,
        relationSnapshots: relations,
      ),
      isTrue,
    );
    expect(
      await checkpointStore.load(objectId: 7, revisionId: 1),
      isNotNull,
    );
    expect(
      await relationStore.listForRevision(sourceObjectId: 7, revisionId: 1),
      hasLength(1),
    );
  });
}

ObjectHistoryCheckpointPayload _checkpoint({
  int objectId = 7,
  required int revisionId,
  int? previousRevisionId,
  List<int> relationPropertyIds = const <int>[21],
}) => ObjectHistoryCheckpointPayload(
  entry: ObjectHistoryEntry(
    objectId: objectId,
    revisionId: revisionId,
    previousRevisionId: previousRevisionId,
    capturedAt: DateTime.utc(2026, 9, 14, 1, revisionId),
    source: ObjectHistorySourceKind.userMutation,
  ),
  title: 'Title $revisionId',
  propertySnapshots: <ObjectHistoryPropertySnapshot>[
    ObjectHistoryPropertySnapshot.fromDefinition(
      property: _property(11, ObjectPropertyType.text),
      value: 'value-$revisionId',
    ),
  ],
  body: ObjectBodyDocument(
    blocks: <ObjectBodyBlock>[
      ObjectBodyBlock(
        id: 'paragraph',
        type: ObjectBodyBlockType.paragraph,
        text: 'Body $revisionId',
      ),
    ],
  ),
  relationRequirements: <ObjectHistoryRelationRequirement>[
    for (final propertyId in relationPropertyIds)
      ObjectHistoryRelationRequirement.fromDefinition(
        _property(propertyId, ObjectPropertyType.objectRelation),
      ),
  ],
);

ObjectHistoryRelationSnapshot _relation({
  int sourceObjectId = 7,
  required int propertyId,
  List<int> targetObjectIds = const <int>[12],
  bool allowsMultipleRelations = true,
}) => ObjectHistoryRelationSnapshot(
  sourceObjectId: sourceObjectId,
  sourceObjectTypeId: 1,
  propertyId: propertyId,
  targetObjectTypeId: 2,
  allowsMultipleRelations: allowsMultipleRelations,
  targetObjectIds: targetObjectIds,
);

ObjectPropertyDefinition _property(int id, ObjectPropertyType type) =>
    ObjectPropertyDefinition(
      id: id,
      objectTypeId: 1,
      name: 'Property $id',
      type: type,
      sortOrder: id,
    );
