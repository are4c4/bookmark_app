import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_group_object_convergence_service.dart';
import 'package:bookmark_app/data/person_group_object_write_service.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic Person create preserves canonical and legacy authority', () async {
    final fixture = await _PersonCreateFixture.create();
    addTearDown(fixture.database.close);

    final objectId = await fixture.service.create(
      databaseId: fixture.personSchema.objectType.id,
      title: 'Ada Lovelace',
    );

    final objects = await fixture.objectStore.listObjects(fixture.personSchema.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.id, objectId);
    expect(objects.single.title, 'Ada Lovelace');

    final legacyPeople = await fixture.database.select(fixture.database.people).get();
    expect(legacyPeople, hasLength(1));
    expect(legacyPeople.single.name, 'Ada Lovelace');
    expect(
      await fixture.personBridge.objectIdForLegacyPerson(fixture.workspaceId, legacyPeople.single.id),
      objectId,
    );
  });

  test('Person Board create preserves canonical authority and applies group preset', () async {
    final fixture = await _PersonCreateFixture.create();
    addTearDown(fixture.database.close);

    final groupSchema = await fixture.groupConvergence.ensureSchema(fixture.workspaceId);
    final group = await PersonGroupObjectWriteService(
      database: fixture.database,
      objectStore: fixture.objectStore,
      systemObjectStore: fixture.systemObjects,
      personBridge: fixture.personBridge,
    ).create(workspaceId: fixture.workspaceId, name: 'Engineers');
    final personType = (await fixture.objectStore.getObjectType(fixture.personSchema.objectType.id))!;

    final objectId = await fixture.service.createInGroup(
      databaseId: personType.id,
      title: 'Grace Hopper',
      groupProperty: groupSchema.personGroupsProperty,
      targetGroup: ObjectGroupBucket<AppObject>(
        key: 'group-${group.canonicalObjectId}',
        label: 'Engineers',
        value: group.canonicalObjectId,
        items: const <AppObject>[],
        isEmptyGroup: false,
      ),
    );

    final person = (await fixture.objectStore.listObjects(personType.id)).single;
    expect(person.id, objectId);
    expect(person.title, 'Grace Hopper');
    expect(
      ObjectRelationValue.fromJson(person.values[groupSchema.personGroupsProperty.id]).objectIds,
      <int>[group.canonicalObjectId],
    );

    final legacyPeople = await fixture.database.select(fixture.database.people).get();
    expect(legacyPeople, hasLength(1));
    expect(legacyPeople.single.name, 'Grace Hopper');
    expect(
      await fixture.personBridge.objectIdForLegacyPerson(fixture.workspaceId, legacyPeople.single.id),
      objectId,
    );
  });

  test('failed Person Board relation preset rolls back canonical and legacy creation', () async {
    final fixture = await _PersonCreateFixture.create();
    addTearDown(fixture.database.close);

    final groupSchema = await fixture.groupConvergence.ensureSchema(fixture.workspaceId);
    final personType = (await fixture.objectStore.getObjectType(fixture.personSchema.objectType.id))!;

    await expectLater(
      fixture.service.createInGroup(
        databaseId: personType.id,
        title: 'No Partial Person',
        groupProperty: groupSchema.personGroupsProperty,
        targetGroup: const ObjectGroupBucket<AppObject>(
          key: 'missing-team',
          label: 'Missing group',
          value: 999999,
          items: <AppObject>[],
          isEmptyGroup: false,
        ),
      ),
      throwsA(anything),
    );

    expect(await fixture.objectStore.listObjects(personType.id), isEmpty);
    expect(await fixture.database.select(fixture.database.people).get(), isEmpty);
  });
}

class _PersonCreateFixture {
  const _PersonCreateFixture({
    required this.database,
    required this.workspaceId,
    required this.objectStore,
    required this.systemObjects,
    required this.personBridge,
    required this.personSchema,
    required this.groupConvergence,
    required this.service,
  });

  final AppDatabase database;
  final int workspaceId;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;
  final PersonObjectBridge personBridge;
  final PersonObjectSchema personSchema;
  final PersonGroupObjectConvergenceService groupConvergence;
  final GenericDatabaseObjectCreateService service;

  static Future<_PersonCreateFixture> create() async {
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
    final personSchema = await personBridge.ensurePersonObjectType(workspaceId);
    final groupConvergence = PersonGroupObjectConvergenceService(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
      personBridge: personBridge,
    );
    final collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final relationMutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    final service = GenericDatabaseObjectCreateService(
      pageLoader: GenericDatabaseCollectionPageLoader(
        genericStore: genericStore,
        collectionResolver: DatabaseCollectionResolver(
          collectionStore: collectionStore,
          objectStore: objectStore,
        ),
      ),
      objectStore: objectStore,
      boardCreate: ObjectBoardCreateService(
        objectStore,
        relationMutations: relationMutations,
      ),
      systemObjects: systemObjects,
    );

    return _PersonCreateFixture(
      database: database,
      workspaceId: workspaceId,
      objectStore: objectStore,
      systemObjects: systemObjects,
      personBridge: personBridge,
      personSchema: personSchema,
      groupConvergence: groupConvergence,
      service: service,
    );
  }
}
