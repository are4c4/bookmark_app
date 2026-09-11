import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_group_object_convergence_service.dart';
import 'package:bookmark_app/data/person_group_object_write_service.dart';
import 'package:bookmark_app/data/person_group_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create and rename keep canonical Person Group authoritative', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    final created = await fixture.writes.create(
      workspaceId: fixture.workspaceId,
      name: '  Writers  ',
    );
    final schema = await fixture.convergence.ensureSchema(fixture.workspaceId);
    var canonical = (await fixture.objectStore.listObjects(
      schema.groupObjectType.id,
    )).single;
    expect(canonical.id, created.canonicalObjectId);
    expect(canonical.title, 'Writers');
    expect(
      canonical.values[schema.legacyGroupIdProperty.id],
      created.legacyGroupId,
    );
    expect((await fixture.groups.listGroups()).single.name, 'Writers');

    final restarted = fixture.newWrites();
    final reused = await restarted.create(
      workspaceId: fixture.workspaceId,
      name: 'writers',
    );
    expect(reused.canonicalObjectId, created.canonicalObjectId);
    expect(reused.legacyGroupId, created.legacyGroupId);
    expect(
      await fixture.objectStore.listObjects(schema.groupObjectType.id),
      hasLength(1),
    );

    await restarted.rename(
      workspaceId: fixture.workspaceId,
      legacyGroupId: created.legacyGroupId,
      name: 'Editors',
    );
    canonical = (await fixture.objectStore.listObjects(
      schema.groupObjectType.id,
    )).single;
    expect(canonical.title, 'Editors');
    expect((await fixture.groups.listGroups()).single.name, 'Editors');
  });

  test(
    'delete detaches canonical memberships and preserves Person Object',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final personId = await PersonObjectWriteService.forDatabase(
        fixture.database,
      ).create(workspaceId: fixture.workspaceId, name: 'Alice');
      final personObjectId = await fixture.personBridge.objectIdForLegacyPerson(
        fixture.workspaceId,
        personId,
      );
      expect(personObjectId, isNotNull);

      final group = await fixture.writes.create(
        workspaceId: fixture.workspaceId,
        name: 'Writers',
      );
      await fixture.convergence.setGroupsForLegacyPerson(
        workspaceId: fixture.workspaceId,
        legacyPersonId: personId,
        legacyGroupIds: <int>[group.legacyGroupId],
      );
      final schema = await fixture.convergence.ensureSchema(
        fixture.workspaceId,
      );
      expect(
        (await RelationTargetService(fixture.objectStore).selectionForMutation(
          workspaceId: fixture.workspaceId,
          sourceObjectId: personObjectId!,
          property: schema.personGroupsProperty,
        )).selectedObjectIds,
        <int>[group.canonicalObjectId],
      );

      await fixture.writes.delete(
        workspaceId: fixture.workspaceId,
        legacyGroupId: group.legacyGroupId,
      );

      expect(await fixture.groups.listGroups(), isEmpty);
      expect(
        await fixture.objectStore.listObjects(schema.groupObjectType.id),
        isEmpty,
      );
      expect(
        (await RelationTargetService(fixture.objectStore).selectionForMutation(
          workspaceId: fixture.workspaceId,
          sourceObjectId: personObjectId,
          property: schema.personGroupsProperty,
        )).selectedObjectIds,
        isEmpty,
      );
      final personSchema = await fixture.personBridge.ensurePersonObjectType(
        fixture.workspaceId,
      );
      expect(
        (await fixture.objectStore.listObjects(personSchema.objectType.id))
            .map((object) => object.id),
        contains(personObjectId),
      );
    },
  );

  test(
    'malformed canonical legacy claim fails before create mutation',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final schema = await fixture.convergence.ensureSchema(
        fixture.workspaceId,
      );
      final corrupt = await fixture.objectStore.createObject(
        objectTypeId: schema.groupObjectType.id,
        title: 'Corrupt',
      );
      await fixture.genericStore.setValue(
        recordId: corrupt,
        propertyId: schema.legacyGroupIdProperty.id,
        value: 'broken',
      );

      await expectLater(
        fixture.writes.create(
          workspaceId: fixture.workspaceId,
          name: 'Writers',
        ),
        throwsA(isA<StateError>()),
      );
      expect(await fixture.groups.listGroups(), isEmpty);
      expect(
        await fixture.objectStore.listObjects(schema.groupObjectType.id),
        hasLength(1),
      );
    },
  );
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
    required this.convergence,
    required this.writes,
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
    final convergence = PersonGroupObjectConvergenceService(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      personBridge: personBridge,
    );
    final writes = PersonGroupObjectWriteService(
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
      convergence: convergence,
      writes: writes,
    );
  }

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;
  final PersonObjectBridge personBridge;
  final PersonGroupStore groups;
  final PersonGroupObjectConvergenceService convergence;
  final PersonGroupObjectWriteService writes;

  PersonGroupObjectWriteService newWrites() => PersonGroupObjectWriteService(
    database: database,
    objectStore: objectStore,
    systemObjectStore: systemObjects,
    personBridge: personBridge,
  );

  Future<void> dispose() => database.close();
}
