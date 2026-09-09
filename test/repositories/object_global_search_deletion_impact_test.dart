import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'committed deletion impact removes target row and refreshes changed sources',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final search = ObjectGlobalSearchService(genericStore);
      final rawIndex = ObjectSearchRepository(genericStore);

      final personTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Person',
      );
      final bookTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Book',
      );
      final authorPropertyId = await objectStore.createRelationProperty(
        objectTypeId: bookTypeId,
        name: 'Author',
        targetObjectTypeId: personTypeId,
        multiple: false,
      );
      final bookType = (await objectStore.getObjectType(bookTypeId))!;
      final authorProperty = bookType.properties.firstWhere(
        (property) => property.id == authorPropertyId,
      );
      final authorId = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'DeletedPersonSearchToken',
      );
      final bookId = await objectStore.createObject(
        objectTypeId: bookTypeId,
        title: 'Relation source',
      );
      final unrelatedId = await objectStore.createObject(
        objectTypeId: bookTypeId,
        title: 'UnrelatedDeletionRefreshToken',
      );
      await objectStore.setRelation(
        objectId: bookId,
        property: authorProperty,
        targetObjectIds: <int>[authorId],
      );
      await search.rebuildWorkspace(workspaceId);

      expect(
        (await rawIndex.search(
          workspaceId: workspaceId,
          rawQuery: 'deletedpersonsearchtoken',
        ))
            .map((hit) => hit.objectId)
            .toSet(),
        <int>{authorId, bookId},
      );

      // Model the state after a canonical deletion transaction has already
      // detached the validated source Relation and deleted the target Object.
      // Search must consume the ids collected by that transaction rather than
      // trying to rediscover backlinks after the edge is gone.
      await objectStore.setRelation(
        objectId: bookId,
        property: authorProperty,
        targetObjectIds: const <int>[],
      );
      await objectStore.deleteObject(authorId);

      expect(
        (await rawIndex.search(
          workspaceId: workspaceId,
          rawQuery: 'deletedpersonsearchtoken',
        ))
            .map((hit) => hit.objectId)
            .toSet(),
        <int>{authorId, bookId},
        reason: 'the canonical FTS projection is stale until focused refresh',
      );

      final projectionChanged = search.projectionChanges.first;
      await search.refreshCommittedDeletionImpact(
        deletedObjectId: authorId,
        changedSourceObjectIds: <int>[bookId, bookId],
      );
      await projectionChanged;

      expect(
        await rawIndex.search(
          workspaceId: workspaceId,
          rawQuery: 'deletedpersonsearchtoken',
        ),
        isEmpty,
        reason: 'deleted row and detached Relation label must both be removed',
      );
      expect(
        (await rawIndex.search(
          workspaceId: workspaceId,
          rawQuery: 'unrelateddeletionrefresh',
        ))
            .map((hit) => hit.objectId),
        <int>[unrelatedId],
        reason: 'focused deletion refresh must not rebuild unrelated Objects',
      );
    },
  );
}
