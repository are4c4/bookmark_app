import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_group_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/person_object_deletion_service.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/person_roles.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late PersonObjectBridge bridge;
  late RelationMutationService relationMutations;
  late PersonObjectDeletionService deletion;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    );
    relationMutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
    );
    deletion = PersonObjectDeletionService(
      database: database,
      personBridge: bridge,
      relationMutations: relationMutations,
      compatibility: PersonObjectDeletionCompatibility(
        database: database,
        objectStore: objectStore,
        personBridge: bridge,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('delete detaches canonical Relations and cleans legacy compatibility atomically', () async {
    final personId = await PersonObjectWriteService.forDatabase(database)
        .create(workspaceId: workspaceId, name: 'Alice', note: 'note');
    final schema = await bridge.ensurePersonObjectType(workspaceId);
    final personObjectId = (await bridge.objectIdForLegacyPerson(
      workspaceId,
      personId,
    ))!;

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final authorPropertyId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: schema.objectType.id,
      multiple: false,
    );
    final authorProperty = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((property) => property.id == authorPropertyId);
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    await relationMutations.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: <int>[personObjectId],
    );

    final legacyPerson = await (database.select(
      database.people,
    )..where((person) => person.id.equals(personId))).getSingle();
    final bookmarkId = await database.addBookmark(
      url: 'https://example.com/person-delete',
      title: 'Legacy Bookmark',
    );
    await database.setPeopleForRole(bookmarkId, 'Author', <Person>[
      legacyPerson,
    ]);
    final groupStore = PersonGroupStore(database);
    final groupId = await groupStore.createGroup('Writers');
    await groupStore.setGroupsForPerson(personId, <int>[groupId]);
    await database.customStatement(
      'INSERT INTO saved_views(name, person_filter_id) VALUES (?, ?)',
      <Object>['Person filter', personId],
    );

    await deletion.delete(workspaceId: workspaceId, personId: personId);

    expect(await objectStore.listObjects(schema.objectType.id), isEmpty);
    expect(await database.select(database.people).get(), isEmpty);
    expect(
      (await database
              .customSelect('SELECT COUNT(*) AS count FROM person_object_links')
              .getSingle())
          .read<int>('count'),
      0,
    );
    final survivingBook = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(survivingBook.values[authorPropertyId])
          .objectIds,
      isEmpty,
    );
    expect(
      (await database
              .customSelect('SELECT COUNT(*) AS count FROM bookmark_people')
              .getSingle())
          .read<int>('count'),
      0,
    );
    expect(
      (await database
              .customSelect(
                'SELECT COUNT(*) AS count FROM person_group_members',
              )
              .getSingle())
          .read<int>('count'),
      0,
    );
    expect(
      (await database.select(database.savedViews).get()).single.personFilterId,
      isNull,
    );

    final restartedBridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    expect(await restartedBridge.syncLegacyPeople(workspaceId), isEmpty);
    expect(await objectStore.listObjects(schema.objectType.id), isEmpty);
  });

  test('delete recovers a missing compatibility link before removing both identities', () async {
    final personId = await PersonObjectWriteService.forDatabase(database)
        .create(workspaceId: workspaceId, name: 'Recoverable');
    final schema = await bridge.ensurePersonObjectType(workspaceId);
    final objectId = (await bridge.objectIdForLegacyPerson(
      workspaceId,
      personId,
    ))!;
    await database.customStatement(
      'DELETE FROM person_object_links WHERE workspace_id = ? AND person_id = ?',
      <Object>[workspaceId, personId],
    );
    expect(await bridge.legacyPersonIdForObject(workspaceId, objectId), isNull);

    await deletion.delete(workspaceId: workspaceId, personId: personId);

    expect(await database.select(database.people).get(), isEmpty);
    expect(await objectStore.listObjects(schema.objectType.id), isEmpty);
  });

  test('late canonical delete failure rolls back Relation detach and legacy cleanup', () async {
    final personId = await PersonObjectWriteService.forDatabase(database)
        .create(workspaceId: workspaceId, name: 'Rollback');
    final schema = await bridge.ensurePersonObjectType(workspaceId);
    final personObjectId = (await bridge.objectIdForLegacyPerson(
      workspaceId,
      personId,
    ))!;

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Person',
      targetObjectTypeId: schema.objectType.id,
      multiple: false,
    );
    final relation = (await objectStore.getObjectType(sourceTypeId))!.properties
        .singleWhere((property) => property.id == relationId);
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source',
    );
    await relationMutations.setRelation(
      objectId: sourceId,
      property: relation,
      targetObjectIds: <int>[personObjectId],
    );

    await database.customStatement('''
        CREATE TRIGGER fail_person_object_delete
        BEFORE DELETE ON generic_records
        WHEN OLD.id = $personObjectId
        BEGIN
          SELECT RAISE(ABORT, 'forced Person Object delete failure');
        END
      ''');

    await expectLater(
      deletion.delete(workspaceId: workspaceId, personId: personId),
      throwsA(anything),
    );

    expect(await database.select(database.people).get(), hasLength(1));
    expect(await objectStore.listObjects(schema.objectType.id), hasLength(1));
    expect(
      (await database
              .customSelect('SELECT COUNT(*) AS count FROM person_object_links')
              .getSingle())
          .read<int>('count'),
      1,
    );
    expect(
      await bridge.objectIdForLegacyPerson(workspaceId, personId),
      personObjectId,
    );
    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(source.values[relationId]).objectIds,
      <int>[personObjectId],
    );
    expect(await objectStore.backlinks(personObjectId), hasLength(1));
  });
}
