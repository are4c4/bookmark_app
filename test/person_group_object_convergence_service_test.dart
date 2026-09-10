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
  test('bootstraps legacy Person groups once through canonical Relations', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
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
    final personId = await PersonObjectWriteService.forDatabase(database)
        .create(workspaceId: workspaceId, name: 'Alice');
    final personObjectId = (await personBridge.objectIdForLegacyPerson(
      workspaceId,
      personId,
    ))!;
    final groups = PersonGroupStore(database);
    final groupId = await groups.createGroup('Writers');
    await groups.setGroupsForPerson(personId, <int>[groupId]);

    final service = PersonGroupObjectConvergenceService(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      personBridge: personBridge,
    );
    expect(await service.converge(workspaceId), <int>[personObjectId]);

    final schema = await service.ensureSchema(workspaceId);
    final groupObjects = await objectStore.listObjects(schema.groupObjectType.id);
    expect(groupObjects, hasLength(1));
    expect(groupObjects.single.title, 'Writers');
    expect(
      groupObjects.single.values[schema.legacyGroupIdProperty.id],
      groupId,
    );
    final selection = await RelationTargetService(objectStore).selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: personObjectId,
      property: schema.personGroupsProperty,
    );
    expect(selection.selectedObjectIds, <int>[groupObjects.single.id]);

    expect(await service.converge(workspaceId), isEmpty);
    expect(await groups.memberIds(groupId), <int>{personId});
  });

  test('fails closed when canonical Person group membership changes after bootstrap', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
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
    final personId = await PersonObjectWriteService.forDatabase(database)
        .create(workspaceId: workspaceId, name: 'Alice');
    final personObjectId = (await personBridge.objectIdForLegacyPerson(
      workspaceId,
      personId,
    ))!;
    final groups = PersonGroupStore(database);
    final groupId = await groups.createGroup('Writers');
    await groups.setGroupsForPerson(personId, <int>[groupId]);
    final service = PersonGroupObjectConvergenceService(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      personBridge: personBridge,
    );
    await service.converge(workspaceId);
    final schema = await service.ensureSchema(workspaceId);

    final mutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    await mutations.setRelation(
      objectId: personObjectId,
      property: schema.personGroupsProperty,
      targetObjectIds: const <int>[],
    );

    await expectLater(
      service.converge(workspaceId),
      throwsA(isA<StateError>()),
    );
    final selection = await RelationTargetService(objectStore).selectionForMutation(
      workspaceId: workspaceId,
      sourceObjectId: personObjectId,
      property: schema.personGroupsProperty,
    );
    expect(selection.selectedObjectIds, isEmpty);
    expect(await groups.memberIds(groupId), <int>{personId});
    expect(await objectStore.listObjects(schema.groupObjectType.id), hasLength(1));
  });
}
