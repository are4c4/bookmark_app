import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_group_object_convergence_service.dart';
import 'package:bookmark_app/data/person_group_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstraps once and remains stable across service restart', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    final personId = await fixture.createPerson('Alice');
    final personObjectId = await fixture.personObjectId(personId);
    final groupId = await fixture.groups.createGroup('Writers');
    await fixture.groups.setGroupsForPerson(personId, <int>[groupId]);

    expect(
      await fixture.service.converge(fixture.workspaceId),
      <int>[personObjectId],
    );

    final schema = await fixture.service.ensureSchema(fixture.workspaceId);
    final groupObjects = await fixture.objectStore.listObjects(
      schema.groupObjectType.id,
    );
    expect(groupObjects, hasLength(1));
    expect(groupObjects.single.title, 'Writers');
    expect(
      groupObjects.single.values[schema.legacyGroupIdProperty.id],
      groupId,
    );
    expect(
      await fixture.selection(schema, personObjectId),
      <int>[groupObjects.single.id],
    );

    final restarted = fixture.newService();
    expect(await restarted.converge(fixture.workspaceId), isEmpty);
    final afterRestart = await fixture.objectStore.listObjects(
      schema.groupObjectType.id,
    );
    expect(afterRestart.single.id, groupObjects.single.id);
    expect(await fixture.groups.memberIds(groupId), <int>{personId});
  });

  test(
    'fails closed when canonical Person group membership changes after bootstrap',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final personId = await fixture.createPerson('Alice');
      final personObjectId = await fixture.personObjectId(personId);
      final groupId = await fixture.groups.createGroup('Writers');
      await fixture.groups.setGroupsForPerson(personId, <int>[groupId]);
      await fixture.service.converge(fixture.workspaceId);
      final schema = await fixture.service.ensureSchema(fixture.workspaceId);

      await fixture.mutations.setRelation(
        objectId: personObjectId,
        property: schema.personGroupsProperty,
        targetObjectIds: const <int>[],
      );

      await expectLater(
        fixture.service.converge(fixture.workspaceId),
        throwsA(isA<StateError>()),
      );
      expect(await fixture.selection(schema, personObjectId), isEmpty);
      expect(await fixture.groups.memberIds(groupId), <int>{personId});
      expect(
        await fixture.objectStore.listObjects(schema.groupObjectType.id),
        hasLength(1),
      );
    },
  );

  test('malformed legacy group identity fails before bootstrap mutation', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    final personId = await fixture.createPerson('Alice');
    final personObjectId = await fixture.personObjectId(personId);
    final groupId = await fixture.groups.createGroup('Writers');
    await fixture.groups.setGroupsForPerson(personId, <int>[groupId]);
    final schema = await fixture.service.ensureSchema(fixture.workspaceId);
    final corruptObjectId = await fixture.objectStore.createObject(
      objectTypeId: schema.groupObjectType.id,
      title: 'Corrupt group claim',
    );
    await fixture.genericStore.setValue(
      recordId: corruptObjectId,
      propertyId: schema.legacyGroupIdProperty.id,
      value: 'not-a-group-id',
    );

    await expectLater(
      fixture.service.converge(fixture.workspaceId),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('malformed legacy identity'),
        ),
      ),
    );

    expect(await fixture.selection(schema, personObjectId), isEmpty);
    final groupObjects = await fixture.objectStore.listObjects(
      schema.groupObjectType.id,
    );
    expect(groupObjects.map((object) => object.id), <int>[corruptObjectId]);
    expect(await fixture.groups.memberIds(groupId), <int>{personId});
  });

  test('duplicate legacy group identity fails before Relation mutation', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    final personId = await fixture.createPerson('Alice');
    final personObjectId = await fixture.personObjectId(personId);
    final groupId = await fixture.groups.createGroup('Writers');
    await fixture.groups.setGroupsForPerson(personId, <int>[groupId]);
    final schema = await fixture.service.ensureSchema(fixture.workspaceId);

    for (final title in <String>['First claim', 'Second claim']) {
      final objectId = await fixture.objectStore.createObject(
        objectTypeId: schema.groupObjectType.id,
        title: title,
      );
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: schema.legacyGroupIdProperty.id,
        value: groupId,
      );
    }

    await expectLater(
      fixture.service.converge(fixture.workspaceId),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('multiple canonical Objects claim'),
        ),
      ),
    );

    expect(await fixture.selection(schema, personObjectId), isEmpty);
    expect(
      await fixture.objectStore.listObjects(schema.groupObjectType.id),
      hasLength(2),
    );
    expect(await fixture.groups.memberIds(groupId), <int>{personId});
  });
}

class _Fixture {
  _Fixture({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.systemObjects,
    required this.personBridge,
    required this.groups,
    required this.service,
  });

  static Future<_Fixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final personBridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    );
    final groups = PersonGroupStore(database);
    final service = PersonGroupObjectConvergenceService(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      personBridge: personBridge,
    );
    return _Fixture(
      database: database,
      workspaceId: workspaceId,
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: systemObjects,
      personBridge: personBridge,
      groups: groups,
      service: service,
    );
  }

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;
  final PersonObjectBridge personBridge;
  final PersonGroupStore groups;
  final PersonGroupObjectConvergenceService service;

  late final RelationMutationService mutations = RelationMutationService(
    objectStore: objectStore,
    genericStore: genericStore,
    bidirectionalStore: BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    ),
  );

  PersonGroupObjectConvergenceService newService() =>
      PersonGroupObjectConvergenceService(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
        personBridge: personBridge,
      );

  Future<int> createPerson(String name) =>
      PersonObjectWriteService.forDatabase(database).create(
        workspaceId: workspaceId,
        name: name,
      );

  Future<int> personObjectId(int personId) async {
    final objectId = await personBridge.objectIdForLegacyPerson(
      workspaceId,
      personId,
    );
    expect(objectId, isNotNull);
    return objectId!;
  }

  Future<List<int>> selection(
    PersonGroupObjectSchema schema,
    int personObjectId,
  ) async {
    final selection = await RelationTargetService(
      objectStore,
    ).selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: personObjectId,
      property: schema.personGroupsProperty,
    );
    return selection.selectedObjectIds;
  }

  Future<void> dispose() => database.close();
}
