import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_history_capture_coordinator.dart';
import 'package:bookmark_app/data/object_history_checkpoint_loader.dart';
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
  test('loads coherent persisted A and B evidence for one revision', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final capture = ObjectHistoryCaptureCoordinator(genericStore);
    final loader = ObjectHistoryCheckpointLoader(genericStore);

    await capture.append(
      checkpoint: _checkpoint(relationPropertyIds: <int>[21, 22]),
      relationSnapshots: <ObjectHistoryRelationSnapshot>[
        _relation(propertyId: 21, targetObjectIds: <int>[12, 11]),
        _relation(propertyId: 22, targetObjectIds: <int>[15]),
      ],
    );

    final loaded = await loader.load(objectId: 7, revisionId: 1);

    expect(loaded, isNotNull);
    expect(loaded!.checkpoint.title, 'Title 1');
    expect(
      loaded.relationSnapshots.map((snapshot) => snapshot.propertyId),
      <int>[21, 22],
    );
    expect(loaded.relationSnapshots.first.targetObjectIds, <int>[12, 11]);
  });

  test('loads zero-Relation checkpoint with empty Relation evidence', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final capture = ObjectHistoryCaptureCoordinator(genericStore);
    final loader = ObjectHistoryCheckpointLoader(genericStore);

    await capture.append(
      checkpoint: _checkpoint(relationPropertyIds: const <int>[]),
      relationSnapshots: const <ObjectHistoryRelationSnapshot>[],
    );

    final loaded = await loader.load(objectId: 7, revisionId: 1);
    expect(loaded, isNotNull);
    expect(loaded!.relationSnapshots, isEmpty);
  });

  test('missing Relation evidence fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final checkpointStore = ObjectHistoryCheckpointStore(genericStore);
    final relationStore = ObjectHistoryRelationStore(genericStore);
    final loader = ObjectHistoryCheckpointLoader(genericStore);

    await checkpointStore.append(
      _checkpoint(relationPropertyIds: <int>[21, 22]),
    );
    await relationStore.append(
      revisionId: 1,
      snapshot: _relation(propertyId: 21),
    );

    await expectLater(
      loader.load(objectId: 7, revisionId: 1),
      throwsStateError,
    );
  });

  test('extra Relation evidence fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final checkpointStore = ObjectHistoryCheckpointStore(genericStore);
    final relationStore = ObjectHistoryRelationStore(genericStore);
    final loader = ObjectHistoryCheckpointLoader(genericStore);

    await checkpointStore.append(_checkpoint(relationPropertyIds: <int>[21]));
    await relationStore.append(
      revisionId: 1,
      snapshot: _relation(propertyId: 21),
    );
    await relationStore.append(
      revisionId: 1,
      snapshot: _relation(propertyId: 22),
    );

    await expectLater(
      loader.load(objectId: 7, revisionId: 1),
      throwsStateError,
    );
  });

  test(
    'missing checkpoint returns null without synthesizing history',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final loader = ObjectHistoryCheckpointLoader(
        GenericDatabaseStore(database),
      );

      expect(await loader.load(objectId: 7, revisionId: 1), isNull);
    },
  );
}

ObjectHistoryCheckpointPayload _checkpoint({
  List<int> relationPropertyIds = const <int>[21],
}) => ObjectHistoryCheckpointPayload(
  entry: ObjectHistoryEntry(
    objectId: 7,
    revisionId: 1,
    capturedAt: DateTime.utc(2026, 9, 14, 2),
    source: ObjectHistorySourceKind.userMutation,
  ),
  title: 'Title 1',
  propertySnapshots: <ObjectHistoryPropertySnapshot>[
    ObjectHistoryPropertySnapshot.fromDefinition(
      property: _property(11, ObjectPropertyType.text),
      value: 'value-1',
    ),
  ],
  body: ObjectBodyDocument(
    blocks: <ObjectBodyBlock>[
      ObjectBodyBlock(
        id: 'paragraph',
        type: ObjectBodyBlockType.paragraph,
        text: 'Body 1',
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
  required int propertyId,
  List<int> targetObjectIds = const <int>[12],
}) => ObjectHistoryRelationSnapshot(
  sourceObjectId: 7,
  sourceObjectTypeId: 1,
  propertyId: propertyId,
  targetObjectTypeId: 2,
  allowsMultipleRelations: true,
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
