import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_search_refresh_planner.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Relation labels share canonical Object index and refresh incrementally',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final search = ObjectSearchRepository(genericStore);
    final refreshPlanner = ObjectSearchRefreshPlanner(objectStore);

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
      title: 'LegacyAuthorToken',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'RelationsBook',
    );
    final unrelatedId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'UnrelatedSearchToken',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: <int>[authorId],
    );

    await search.rebuildWorkspace(workspaceId);

    final legacyIds =
        (await search.search(workspaceId: workspaceId, rawQuery: 'legacyauthor'))
            .map((hit) => hit.objectId)
            .toSet();
    expect(legacyIds, containsAll(<int>[authorId, bookId]));
    expect(
      await search.search(workspaceId: workspaceId, rawQuery: '$authorId'),
      isEmpty,
      reason: 'Relation target ids must remain structural-only metadata',
    );

    await objectStore.renameObject(authorId, 'CurrentAuthorToken');
    for (final objectId in await refreshPlanner.forObjectLabelChange(authorId)) {
      await search.refreshObject(objectId);
    }

    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'currentauthor'))
          .map((hit) => hit.objectId),
      contains(bookId),
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'legacyauthor'))
          .map((hit) => hit.objectId),
      isNot(contains(bookId)),
      reason: 'target rename must remove stale labels from backlink sources',
    );

    await objectStore.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: const <int>[],
    );
    await search.refreshObject(bookId);

    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'currentauthor'))
          .map((hit) => hit.objectId),
      isNot(contains(bookId)),
      reason: 'clearing a Relation must clear its source search tokens',
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'unrelatedsearch'))
          .map((hit) => hit.objectId),
      contains(unrelatedId),
      reason: 'focused Relation refresh must leave unrelated rows intact',
    );
  });
}
