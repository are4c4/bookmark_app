import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/canonical_object_mutation_impact_sink.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/relation_target_quick_create_policy.dart';
import 'package:bookmark_app/data/relation_target_quick_create_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Relation Person quick-create refreshes canonical Search', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final defaults = ObjectTypeDefaultsStore(genericStore);
    final tagBridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    );
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    );
    final policy = RelationTargetQuickCreatePolicy(
      objectStore: objectStore,
      systemObjects: systemObjects,
    );
    final search = ObjectGlobalSearchService(genericStore);
    final searchIndex = ObjectSearchRepository(genericStore);
    await search.rebuildWorkspace(workspaceId);
    final committedObjectIds = <int>[];
    final impactSink = CanonicalObjectMutationImpactSink(
      onObjectCommitted: (objectId) async {
        committedObjectIds.add(objectId);
        await search.refreshObjectLabelDependents(objectId);
      },
      onDeletionCommitted: (impact) async {},
    );
    final personBridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    );
    final personSchema = await personBridge.ensurePersonObjectType(workspaceId);
    final quickCreate = RelationTargetQuickCreateService(
      policy: policy,
      objectStore: objectStore,
      tagBridge: tagBridge,
      weblinks: weblinks,
      canonicalObjectMutationImpactSink: impactSink,
    );

    final created = await quickCreate.create(
      workspaceId: workspaceId,
      targetObjectTypeId: personSchema.objectType.id,
      input: 'Grace Hopper',
    );

    expect(created, isNotNull);
    expect(committedObjectIds, <int>[created!.id]);
    expect(
      (await searchIndex.search(
        workspaceId: workspaceId,
        rawQuery: 'grace',
      )).map((hit) => hit.objectId),
      <int>[created.id],
    );
  });

  test(
    'generic Person delete refreshes target and Relation label source',
    () async {
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
      final legacyPersonId = await PersonObjectWriteService.forDatabase(
        database,
      ).create(workspaceId: workspaceId, name: 'DeleteToken Person');
      final personSchema = await personBridge.ensurePersonObjectType(
        workspaceId,
      );
      final personObjectId = (await personBridge.objectIdForLegacyPerson(
        workspaceId,
        legacyPersonId,
      ))!;
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
        title: 'Relation source',
      );
      final search = ObjectGlobalSearchService(genericStore);
      final searchIndex = ObjectSearchRepository(genericStore);
      final deletedObjectIds = <int>[];
      final detachedSourceIds = <Set<int>>[];
      final impactSink = CanonicalObjectMutationImpactSink(
        onObjectCommitted: (objectId) async {},
        onDeletionCommitted: (impact) async {
          deletedObjectIds.add(impact.deletedObjectId);
          detachedSourceIds.add(impact.detachedSourceObjectIds.toSet());
          await search.refreshCommittedDeletionImpact(
            deletedObjectId: impact.deletedObjectId,
            changedSourceObjectIds: impact.detachedSourceObjectIds,
          );
        },
      );
      final services = GenericDatabasePageServices.fromStores(
        genericStore: genericStore,
        objectStore: objectStore,
        canonicalObjectMutationImpactSink: impactSink,
      );
      await services.relationMutations.setRelation(
        objectId: bookObjectId,
        property: authorProperty,
        targetObjectIds: <int>[personObjectId],
      );
      await search.rebuildWorkspace(workspaceId);

      expect(
        (await searchIndex.search(
          workspaceId: workspaceId,
          rawQuery: 'deletetoken',
        )).map((hit) => hit.objectId).toSet(),
        <int>{personObjectId, bookObjectId},
      );

      await services.relationMutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: personSchema.objectType.id,
        objectId: personObjectId,
      );

      expect(deletedObjectIds, <int>[personObjectId]);
      expect(detachedSourceIds, hasLength(1));
      expect(detachedSourceIds.single, contains(bookObjectId));
      expect(
        await searchIndex.search(
          workspaceId: workspaceId,
          rawQuery: 'deletetoken',
        ),
        isEmpty,
      );
    },
  );

  test('failed Person delete emits no Search refresh', () async {
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
    final legacyPersonId = await PersonObjectWriteService.forDatabase(database)
        .create(workspaceId: workspaceId, name: 'Filtered Search Person');
    final personSchema = await personBridge.ensurePersonObjectType(workspaceId);
    final personObjectId = (await personBridge.objectIdForLegacyPerson(
      workspaceId,
      legacyPersonId,
    ))!;
    final search = ObjectGlobalSearchService(genericStore);
    final searchIndex = ObjectSearchRepository(genericStore);
    await search.rebuildWorkspace(workspaceId);
    final deletedObjectIds = <int>[];
    final impactSink = CanonicalObjectMutationImpactSink(
      onObjectCommitted: (objectId) async {},
      onDeletionCommitted: (impact) async {
        deletedObjectIds.add(impact.deletedObjectId);
        await search.refreshCommittedDeletionImpact(
          deletedObjectId: impact.deletedObjectId,
          changedSourceObjectIds: impact.detachedSourceObjectIds,
        );
      },
    );
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
      canonicalObjectMutationImpactSink: impactSink,
    );
    await database.customStatement(
      'INSERT INTO saved_views(name, person_filter_id) VALUES (?, ?)',
      <Object>['Person filter', legacyPersonId],
    );

    await expectLater(
      services.relationMutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: personSchema.objectType.id,
        objectId: personObjectId,
      ),
      throwsA(isA<StateError>()),
    );

    expect(deletedObjectIds, isEmpty);
    expect(
      (await searchIndex.search(
        workspaceId: workspaceId,
        rawQuery: 'filtered',
      )).map((hit) => hit.objectId),
      <int>[personObjectId],
    );
  });
}
