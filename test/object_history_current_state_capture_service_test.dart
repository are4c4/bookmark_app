import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_history_checkpoint_loader.dart';
import 'package:bookmark_app/data/object_history_checkpoint_store.dart';
import 'package:bookmark_app/data/object_history_current_state_capture_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'captures canonical A+B evidence, dedupes same state, and extends chain',
    () async {
      final fixture = await _Fixture.createMemory();
      addTearDown(fixture.database.close);

      final targetTypeId = await fixture.objectStore.createObjectType(
        workspaceId: fixture.workspaceId,
        name: 'Target',
      );
      final mutableId = await fixture.objectStore.createProperty(
        objectTypeId: fixture.objectTypeId,
        name: 'Status',
        type: ObjectPropertyType.text,
      );
      final identityId = await fixture.objectStore.createProperty(
        objectTypeId: fixture.objectTypeId,
        name: 'Identity date',
        type: ObjectPropertyType.date,
        config: const <String, dynamic>{
          ObjectPropertyDefinition.identityManagedConfigKey: true,
        },
      );
      final relationId = await fixture.objectStore.createRelationProperty(
        objectTypeId: fixture.objectTypeId,
        name: 'Related',
        targetObjectTypeId: targetTypeId,
        multiple: true,
      );
      final targetA = await fixture.objectStore.createObject(
        objectTypeId: targetTypeId,
        title: 'Target A',
      );
      final targetB = await fixture.objectStore.createObject(
        objectTypeId: targetTypeId,
        title: 'Target B',
      );
      final objectId = await fixture.objectStore.createObject(
        objectTypeId: fixture.objectTypeId,
        title: 'Before',
      );
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: mutableId,
        value: 'draft',
      );
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: identityId,
        value: '2026-09-19',
      );
      await fixture.bodyStore.write(
        objectId: objectId,
        document: _body('body-before'),
      );

      final sourceType = (await fixture.objectStore.getObjectType(
        fixture.objectTypeId,
      ))!;
      final relation = sourceType.properties.singleWhere(
        (property) => property.id == relationId,
      );
      await fixture.relationMutation.setRelation(
        objectId: objectId,
        property: relation,
        targetObjectIds: <int>[targetB, targetA],
      );

      final capture = ObjectHistoryCurrentStateCaptureService.fromStores(
        genericStore: fixture.genericStore,
        objectStore: fixture.objectStore,
        bodyStore: fixture.bodyStore,
        clock: () => DateTime.utc(2026, 9, 19, 1),
      );
      final loader = ObjectHistoryCheckpointLoader(fixture.genericStore);
      final checkpointStore = ObjectHistoryCheckpointStore(
        fixture.genericStore,
      );

      final first = await capture.captureCurrent(
        objectTypeId: fixture.objectTypeId,
        objectId: objectId,
      );
      expect(first.revisionId, 1);
      expect(first.appended, isTrue);

      final whole1 = (await loader.load(objectId: objectId, revisionId: 1))!;
      expect(whole1.checkpoint.entry.previousRevisionId, isNull);
      expect(whole1.checkpoint.title, 'Before');
      expect(
        {
          for (final snapshot in whole1.checkpoint.propertySnapshots)
            snapshot.propertyId: snapshot.value,
        },
        <int, dynamic>{mutableId: 'draft', identityId: '2026-09-19'},
      );
      expect(whole1.checkpoint.body.toJson(), _body('body-before').toJson());
      expect(whole1.relationSnapshots, hasLength(1));
      expect(whole1.relationSnapshots.single.propertyId, relationId);
      expect(whole1.relationSnapshots.single.targetObjectIds, <int>[
        targetB,
        targetA,
      ]);

      final duplicate = await capture.captureCurrent(
        objectTypeId: fixture.objectTypeId,
        objectId: objectId,
      );
      expect(duplicate.revisionId, 1);
      expect(duplicate.appended, isFalse);
      expect(await checkpointStore.list(objectId), hasLength(1));

      await fixture.objectStore.renameObject(objectId, 'After');
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: mutableId,
        value: 'done',
      );
      await fixture.bodyStore.write(
        objectId: objectId,
        document: _body('body-after'),
      );
      await fixture.relationMutation.setRelation(
        objectId: objectId,
        property: relation,
        targetObjectIds: <int>[targetA],
      );

      final second = await capture.captureCurrent(
        objectTypeId: fixture.objectTypeId,
        objectId: objectId,
      );
      expect(second.revisionId, 2);
      expect(second.appended, isTrue);

      final whole2 = (await loader.load(objectId: objectId, revisionId: 2))!;
      expect(whole2.checkpoint.entry.previousRevisionId, 1);
      expect(whole2.checkpoint.title, 'After');
      expect(
        {
          for (final snapshot in whole2.checkpoint.propertySnapshots)
            snapshot.propertyId: snapshot.value,
        },
        <int, dynamic>{mutableId: 'done', identityId: '2026-09-19'},
      );
      expect(whole2.checkpoint.body.toJson(), _body('body-after').toJson());
      expect(whole2.relationSnapshots.single.targetObjectIds, <int>[targetA]);

      final chain = await checkpointStore.list(objectId);
      expect(chain.map((item) => item.entry.revisionId), <int>[1, 2]);
      expect(chain.last.entry.previousRevisionId, 1);
    },
  );

  test('concurrent same-state capture keeps one revision', () async {
    final fixture = await _Fixture.createMemory();
    addTearDown(fixture.database.close);
    final objectId = await fixture.objectStore.createObject(
      objectTypeId: fixture.objectTypeId,
      title: 'Concurrent',
    );
    final capture = ObjectHistoryCurrentStateCaptureService.fromStores(
      genericStore: fixture.genericStore,
      objectStore: fixture.objectStore,
      bodyStore: fixture.bodyStore,
    );

    final results = await Future.wait(
      <Future<ObjectHistoryCurrentStateCaptureResult>>[
        capture.captureCurrent(
          objectTypeId: fixture.objectTypeId,
          objectId: objectId,
        ),
        capture.captureCurrent(
          objectTypeId: fixture.objectTypeId,
          objectId: objectId,
        ),
      ],
    );

    expect(results.map((item) => item.revisionId).toSet(), <int>{1});
    expect(results.where((item) => item.appended), hasLength(1));
    expect(
      await ObjectHistoryCheckpointStore(fixture.genericStore).list(objectId),
      hasLength(1),
    );
  });

  test(
    'malformed current Property metadata and value fail before append',
    () async {
      final fixture = await _Fixture.createMemory();
      addTearDown(fixture.database.close);
      final propertyId = await fixture.objectStore.createProperty(
        objectTypeId: fixture.objectTypeId,
        name: 'Status',
        type: ObjectPropertyType.text,
      );
      final objectId = await fixture.objectStore.createObject(
        objectTypeId: fixture.objectTypeId,
        title: 'Strict',
      );
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: propertyId,
        value: 'ok',
      );
      final capture = ObjectHistoryCurrentStateCaptureService.fromStores(
        genericStore: fixture.genericStore,
        objectStore: fixture.objectStore,
        bodyStore: fixture.bodyStore,
      );
      final store = ObjectHistoryCheckpointStore(fixture.genericStore);

      await fixture.database.customStatement(
        'UPDATE generic_properties SET config_json = ? WHERE id = ?',
        <Object>['{broken', propertyId],
      );
      await expectLater(
        capture.captureCurrent(
          objectTypeId: fixture.objectTypeId,
          objectId: objectId,
        ),
        throwsStateError,
      );
      expect(await store.list(objectId), isEmpty);

      await fixture.database.customStatement(
        'UPDATE generic_properties SET config_json = ? WHERE id = ?',
        <Object>['{}', propertyId],
      );
      await fixture.database.customStatement(
        'UPDATE generic_values SET value_json = ? WHERE record_id = ? AND property_id = ?',
        <Object>['{broken', objectId, propertyId],
      );
      await expectLater(
        capture.captureCurrent(
          objectTypeId: fixture.objectTypeId,
          objectId: objectId,
        ),
        throwsStateError,
      );
      expect(await store.list(objectId), isEmpty);
    },
  );

  test('captured whole checkpoint survives database reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bookmark-history-capture-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/history.sqlite');

    final database1 = AppDatabase.forTesting(NativeDatabase(file));
    final workspaceId = await WorkspaceStore(database1).initialize();
    final genericStore1 = GenericDatabaseStore(database1);
    final objectStore1 = ObjectStore(genericStore1);
    final bodyStore1 = ObjectBodyStore(genericStore1);
    final objectTypeId = await objectStore1.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final propertyId = await objectStore1.createProperty(
      objectTypeId: objectTypeId,
      name: 'Status',
      type: ObjectPropertyType.text,
    );
    final objectId = await objectStore1.createObject(
      objectTypeId: objectTypeId,
      title: 'Restart-safe',
    );
    await genericStore1.setValue(
      recordId: objectId,
      propertyId: propertyId,
      value: 'saved',
    );
    await bodyStore1.write(
      objectId: objectId,
      document: _body('persisted body'),
    );
    await ObjectHistoryCurrentStateCaptureService.fromStores(
      genericStore: genericStore1,
      objectStore: objectStore1,
      bodyStore: bodyStore1,
    ).captureCurrent(objectTypeId: objectTypeId, objectId: objectId);
    await database1.close();

    final database2 = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(database2.close);
    final whole = await ObjectHistoryCheckpointLoader(
      GenericDatabaseStore(database2),
    ).load(objectId: objectId, revisionId: 1);

    expect(whole, isNotNull);
    expect(whole!.checkpoint.title, 'Restart-safe');
    expect(whole.checkpoint.propertySnapshots.single.value, 'saved');
    expect(whole.checkpoint.body.toJson(), _body('persisted body').toJson());
  });
}

ObjectBodyDocument _body(String text) => ObjectBodyDocument(
  blocks: <ObjectBodyBlock>[
    ObjectBodyBlock.paragraph(id: 'paragraph', text: text),
  ],
);

class _Fixture {
  _Fixture({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.bodyStore,
    required this.objectTypeId,
    required this.relationMutation,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final ObjectBodyStore bodyStore;
  final int objectTypeId;
  final RelationMutationService relationMutation;

  static Future<_Fixture> createMemory() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    return _Fixture(
      database: database,
      workspaceId: workspaceId,
      genericStore: genericStore,
      objectStore: objectStore,
      bodyStore: bodyStore,
      objectTypeId: objectTypeId,
      relationMutation: RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      ),
    );
  }
}
