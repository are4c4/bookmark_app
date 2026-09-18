import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_history_checkpoint_loader.dart';
import 'package:bookmark_app/data/object_history_restore_executor.dart';
import 'package:bookmark_app/data/object_history_restore_preparation_service.dart';
import 'package:bookmark_app/data/object_store.dart';
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
    'whole restore rejects a changed identity-managed Value before mutation',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final identity = await fixture.createValueProperty(
        'Date',
        identityManaged: true,
      );
      final mutable = await fixture.createValueProperty('Note');
      final objectId = await fixture.createObject('Current title');
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: identity.id,
        value: '2026-09-19',
      );
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: mutable.id,
        value: 'current note',
      );
      await fixture.bodyStore.write(
        objectId: objectId,
        document: _body('current body'),
      );

      final historical = _checkpoint(
        objectId: objectId,
        revisionId: 2,
        title: 'Historical title',
        body: _body('historical body'),
        values: <ObjectPropertyDefinition, dynamic>{
          identity: '2026-09-18',
          mutable: 'historical note',
        },
      );
      final current = _checkpoint(
        objectId: objectId,
        revisionId: 3,
        title: 'Current title',
        body: _body('current body'),
        values: <ObjectPropertyDefinition, dynamic>{
          identity: '2026-09-19',
          mutable: 'current note',
        },
      );
      var relationCalls = 0;
      final executor = ObjectHistoryRestoreExecutor(
        genericStore: fixture.genericStore,
        loadCurrent: () async => current,
        applyRelationRestore: (_) async {
          relationCalls += 1;
          return ObjectHistoryRelationRestoreImpact(
            changedObjectIds: const <int>[],
          );
        },
      );

      await expectLater(
        executor.execute(
          preparation: _preparation(
            historical: historical,
            current: current,
            scope: ObjectHistoryRestoreScope.wholeObject(),
          ),
          expectedCurrentRevisionId: 3,
        ),
        throwsStateError,
      );

      final preserved = await fixture.object(objectId);
      expect(preserved.title, 'Current title');
      expect(preserved.values[identity.id], '2026-09-19');
      expect(preserved.values[mutable.id], 'current note');
      expect(
        (await fixture.bodyStore.read(objectId)).toJson(),
        _body('current body').toJson(),
      );
      expect(relationCalls, 0);
    },
  );

  test('selective changed identity-managed Value restore rejects', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    final identity = await fixture.createValueProperty(
      'Date',
      identityManaged: true,
    );
    final objectId = await fixture.createObject('Current title');
    await fixture.genericStore.setValue(
      recordId: objectId,
      propertyId: identity.id,
      value: '2026-09-19',
    );
    final historical = _checkpoint(
      objectId: objectId,
      revisionId: 2,
      title: 'Current title',
      values: <ObjectPropertyDefinition, dynamic>{identity: '2026-09-18'},
    );
    final current = _checkpoint(
      objectId: objectId,
      revisionId: 3,
      title: 'Current title',
      values: <ObjectPropertyDefinition, dynamic>{identity: '2026-09-19'},
    );
    final executor = ObjectHistoryRestoreExecutor(
      genericStore: fixture.genericStore,
      loadCurrent: () async => current,
      applyRelationRestore: (_) async =>
          ObjectHistoryRelationRestoreImpact(changedObjectIds: const <int>[]),
    );

    await expectLater(
      executor.execute(
        preparation: _preparation(
          historical: historical,
          current: current,
          scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
            ObjectHistoryFieldTarget.property(identity.id),
          ]),
        ),
        expectedCurrentRevisionId: 3,
      ),
      throwsStateError,
    );

    expect((await fixture.object(objectId)).values[identity.id], '2026-09-19');
  });

  test(
    'matching identity evidence does not block unrelated mutable restore',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);

      final identity = await fixture.createValueProperty(
        'Date',
        identityManaged: true,
      );
      final mutable = await fixture.createValueProperty('Note');
      final objectId = await fixture.createObject('Current title');
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: identity.id,
        value: '2026-09-19',
      );
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: mutable.id,
        value: 'current note',
      );
      await fixture.bodyStore.write(
        objectId: objectId,
        document: _body('current body'),
      );
      final historical = _checkpoint(
        objectId: objectId,
        revisionId: 2,
        title: 'Historical title',
        body: _body('historical body'),
        values: <ObjectPropertyDefinition, dynamic>{
          identity: '2026-09-19',
          mutable: 'historical note',
        },
      );
      final current = _checkpoint(
        objectId: objectId,
        revisionId: 3,
        title: 'Current title',
        body: _body('current body'),
        values: <ObjectPropertyDefinition, dynamic>{
          identity: '2026-09-19',
          mutable: 'current note',
        },
      );
      final executor = ObjectHistoryRestoreExecutor(
        genericStore: fixture.genericStore,
        loadCurrent: () async => current,
        applyRelationRestore: (_) async =>
            ObjectHistoryRelationRestoreImpact(changedObjectIds: const <int>[]),
      );

      await executor.execute(
        preparation: _preparation(
          historical: historical,
          current: current,
          scope: ObjectHistoryRestoreScope.wholeObject(),
        ),
        expectedCurrentRevisionId: 3,
      );

      final restored = await fixture.object(objectId);
      expect(restored.title, 'Historical title');
      expect(restored.values[identity.id], '2026-09-19');
      expect(restored.values[mutable.id], 'historical note');
      expect(
        (await fixture.bodyStore.read(objectId)).toJson(),
        _body('historical body').toJson(),
      );
    },
  );
}

ObjectHistoryRestorePreparation _preparation({
  required ObjectHistoryCheckpointPayload historical,
  required ObjectHistoryCheckpointPayload current,
  required ObjectHistoryRestoreScope scope,
}) {
  final preview = const ObjectHistoryCheckpointRestorePlanner().preview(
    historical: historical,
    current: current,
    scope: scope,
  );
  return ObjectHistoryRestorePreparation(
    historical: ObjectHistoryWholeCheckpoint(
      checkpoint: historical,
      relationSnapshots: const <ObjectHistoryRelationSnapshot>[],
    ),
    preview: preview,
    relationPlans: const <ObjectHistoryRelationRestorePlan>[],
  );
}

ObjectHistoryCheckpointPayload _checkpoint({
  required int objectId,
  required int revisionId,
  required String title,
  required Map<ObjectPropertyDefinition, dynamic> values,
  ObjectBodyDocument body = const ObjectBodyDocument(),
}) => ObjectHistoryCheckpointPayload(
  entry: ObjectHistoryEntry(
    objectId: objectId,
    revisionId: revisionId,
    previousRevisionId: revisionId - 1,
    capturedAt: DateTime.utc(2026, 9, 19, revisionId),
    source: ObjectHistorySourceKind.userMutation,
  ),
  title: title,
  propertySnapshots: <ObjectHistoryPropertySnapshot>[
    for (final entry in values.entries)
      ObjectHistoryPropertySnapshot.fromDefinition(
        property: entry.key,
        value: entry.value,
      ),
  ],
  body: body,
);

ObjectBodyDocument _body(String text) => ObjectBodyDocument(
  blocks: <ObjectBodyBlock>[
    ObjectBodyBlock.paragraph(id: 'paragraph', text: text),
  ],
);

class _Fixture {
  _Fixture({
    required this.database,
    required this.genericStore,
    required this.objectStore,
    required this.bodyStore,
    required this.objectTypeId,
  });

  final AppDatabase database;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final ObjectBodyStore bodyStore;
  final int objectTypeId;

  static Future<_Fixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Daily Note-like',
    );
    return _Fixture(
      database: database,
      genericStore: genericStore,
      objectStore: objectStore,
      bodyStore: bodyStore,
      objectTypeId: objectTypeId,
    );
  }

  Future<ObjectPropertyDefinition> createValueProperty(
    String name, {
    bool identityManaged = false,
  }) async {
    final propertyId = await objectStore.createProperty(
      objectTypeId: objectTypeId,
      name: name,
      type: ObjectPropertyType.text,
      config: identityManaged
          ? const <String, dynamic>{
              ObjectPropertyDefinition.identityManagedConfigKey: true,
            }
          : const <String, dynamic>{},
    );
    return (await objectStore.getObjectType(objectTypeId))!.properties
        .singleWhere((property) => property.id == propertyId);
  }

  Future<int> createObject(String title) =>
      objectStore.createObject(objectTypeId: objectTypeId, title: title);

  Future<AppObject> object(int objectId) async =>
      (await objectStore.listObjects(objectTypeId))
          .singleWhere((object) => object.id == objectId);
}
