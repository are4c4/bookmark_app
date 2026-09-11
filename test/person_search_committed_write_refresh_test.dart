import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/canonical_object_mutation_impact_sink.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('committed Person create/update refreshes canonical Search and label dependents', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final producerSearch = ObjectGlobalSearchService(genericStore);
    final pageSearch = ObjectGlobalSearchService(genericStore);
    final committedObjectIds = <int>[];
    final workspaceStore = WorkspaceStore(
      database,
      canonicalObjectMutationImpactSink: CanonicalObjectMutationImpactSink(
        onObjectCommitted: (objectId) async {
          committedObjectIds.add(objectId);
          await producerSearch.refreshObjectLabelDependents(objectId);
        },
        onDeletionCommitted: (impact) =>
            producerSearch.refreshCommittedDeletionImpact(
              deletedObjectId: impact.deletedObjectId,
              changedSourceObjectIds: impact.detachedSourceObjectIds,
            ),
      ),
    );
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    addTearDown(lifecycleStore.dispose);
    await producerSearch.rebuildWorkspace(workspaceId);

    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );

    final createProjection = pageSearch.projectionChanges.first;
    final personId = await repository.createPerson(
      'CommittedCreateToken',
      note: 'InitialPersonNote',
    );
    await createProjection;

    expect(committedObjectIds, hasLength(1));
    final personObjectId = committedObjectIds.single;
    expect(
      (await pageSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'committedcreate',
      )).map((hit) => hit.object.id),
      <int>[personObjectId],
    );

    final bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    final personSchema = await bridge.ensurePersonObjectType(workspaceId);
    expect(
      await bridge.objectIdForLegacyPerson(workspaceId, personId),
      personObjectId,
    );

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person Search Source',
    );
    final relationPropertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Related Person',
      targetObjectTypeId: personSchema.objectType.id,
      multiple: false,
    );
    final sourceType = (await objectStore.getObjectType(sourceTypeId))!;
    final relationProperty = sourceType.properties.singleWhere(
      (property) => property.id == relationPropertyId,
    );
    final sourceObjectId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'DependentPersonSearchSource',
    );
    await objectStore.setRelation(
      objectId: sourceObjectId,
      property: relationProperty,
      targetObjectIds: <int>[personObjectId],
    );
    await producerSearch.refreshObject(sourceObjectId);

    expect(
      (await pageSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'committedcreate',
      )).map((hit) => hit.object.id).toSet(),
      <int>{personObjectId, sourceObjectId},
    );

    final person = (await repository.watchPeople().first).singleWhere(
      (candidate) => candidate.id == personId,
    );
    final updateProjection = pageSearch.projectionChanges.first;
    await repository.updatePerson(
      person,
      'CommittedUpdateToken',
      'CommittedNoteToken',
    );
    await updateProjection;

    expect(committedObjectIds, <int>[personObjectId, personObjectId]);
    expect(
      (await pageSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'committedupdate',
      )).map((hit) => hit.object.id).toSet(),
      <int>{personObjectId, sourceObjectId},
    );
    expect(
      await pageSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'committedcreate',
      ),
      isEmpty,
    );
    expect(
      (await pageSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'committednote',
      )).map((hit) => hit.object.id),
      <int>[personObjectId],
    );

    final callbackCountBeforeDuplicate = committedObjectIds.length;
    expect(await repository.createPerson('CommittedUpdateToken'), personId);
    expect(committedObjectIds, hasLength(callbackCountBeforeDuplicate));

    final conflictPersonId = await repository.createPerson(
      'CommittedConflictTargetToken',
    );
    expect(conflictPersonId, isNot(personId));
    final callbackCountBeforeFailure = committedObjectIds.length;
    final currentPerson = (await repository.watchPeople().first).singleWhere(
      (candidate) => candidate.id == personId,
    );

    await expectLater(
      repository.updatePerson(
        currentPerson,
        'CommittedConflictTargetToken',
        'RolledBackNoteToken',
      ),
      throwsA(anything),
    );
    expect(committedObjectIds, hasLength(callbackCountBeforeFailure));
    expect(
      (await pageSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'committedupdate',
      )).map((hit) => hit.object.id).toSet(),
      <int>{personObjectId, sourceObjectId},
      reason: 'failed Person projection must roll back canonical Search facts',
    );
    expect(
      await pageSearch.search(
        workspaceId: workspaceId,
        rawQuery: 'rolledbacknote',
      ),
      isEmpty,
    );
  });
}
