import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic Person delete removes legacy projection, detaches backlinks, and preserves profile Image', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    );
    final personId = await PersonObjectWriteService.forDatabase(database)
        .create(workspaceId: workspaceId, name: 'Generic delete');
    final personSchema = await bridge.ensurePersonObjectType(workspaceId);
    final personObjectId = (await bridge.objectIdForLegacyPerson(
      workspaceId,
      personId,
    ))!;

    final imageDefinition = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    ).ensureDefinition(workspaceId);
    final imageObjectId = await objectStore.createObject(
      objectTypeId: imageDefinition.objectType.id,
      title: 'Profile image',
    );
    final profileImage = await systemObjects.ensureRelationProperty(
      objectTypeId: personSchema.objectType.id,
      name: 'Profile Image',
      targetObjectTypeId: imageDefinition.objectType.id,
      multiple: false,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final authorPropertyId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personSchema.objectType.id,
      multiple: false,
    );
    final authorProperty = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((property) => property.id == authorPropertyId);
    final bookObjectId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );

    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    await services.relationMutations.setRelation(
      objectId: personObjectId,
      property: profileImage,
      targetObjectIds: <int>[imageObjectId],
    );
    await services.relationMutations.setRelation(
      objectId: bookObjectId,
      property: authorProperty,
      targetObjectIds: <int>[personObjectId],
    );

    await services.relationMutations.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: personSchema.objectType.id,
      objectId: personObjectId,
    );

    expect(await database.select(database.people).get(), isEmpty);
    expect(await objectStore.listObjects(personSchema.objectType.id), isEmpty);
    expect(
      (await objectStore.listObjects(imageDefinition.objectType.id))
          .map((object) => object.id),
      contains(imageObjectId),
    );
    final survivingBook = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(survivingBook.values[authorPropertyId])
          .objectIds,
      isEmpty,
    );
    expect(await objectStore.backlinks(personObjectId), isEmpty);

    final restartedBridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    expect(await restartedBridge.syncLegacyPeople(workspaceId), isEmpty);
    expect(await objectStore.listObjects(personSchema.objectType.id), isEmpty);
  });

  test(
    'generic Person delete fails closed while a Saved View references it',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final bridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
      );
      final personId = await PersonObjectWriteService.forDatabase(database)
          .create(workspaceId: workspaceId, name: 'Filtered Person');
      final personSchema = await bridge.ensurePersonObjectType(workspaceId);
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
        targetObjectTypeId: personSchema.objectType.id,
        multiple: false,
      );
      final relation = (await objectStore.getObjectType(sourceTypeId))!
          .properties
          .singleWhere((property) => property.id == relationId);
      final sourceObjectId = await objectStore.createObject(
        objectTypeId: sourceTypeId,
        title: 'Source',
      );
      final services = GenericDatabasePageServices.fromStores(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      await services.relationMutations.setRelation(
        objectId: sourceObjectId,
        property: relation,
        targetObjectIds: <int>[personObjectId],
      );
      await database.customStatement(
        'INSERT INTO saved_views(name, person_filter_id) VALUES (?, ?)',
        <Object>['Person filter', personId],
      );

      await expectLater(
        services.relationMutations.deleteObject(
          workspaceId: workspaceId,
          objectTypeId: personSchema.objectType.id,
          objectId: personObjectId,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Saved View'),
          ),
        ),
      );

      expect(
        await objectStore.listObjects(personSchema.objectType.id),
        hasLength(1),
      );
      expect(await database.select(database.people).get(), hasLength(1));
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
      expect(
        (await database.select(database.savedViews).get())
            .single
            .personFilterId,
        personId,
      );
    },
  );

  test('generic delete permits a native canonical Person without legacy projection', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    final personSchema = await bridge.ensurePersonObjectType(workspaceId);
    final nativePersonObjectId = await objectStore.createObject(
      objectTypeId: personSchema.objectType.id,
      title: 'Native Person',
    );
    expect(await database.select(database.people).get(), isEmpty);

    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    await services.relationMutations.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: personSchema.objectType.id,
      objectId: nativePersonObjectId,
    );

    expect(await objectStore.listObjects(personSchema.objectType.id), isEmpty);
    expect(await database.select(database.people).get(), isEmpty);
  });
}
