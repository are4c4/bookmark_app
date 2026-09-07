import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'serialized Relation/index disagreement drops stale search labels',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final search = ObjectSearchRepository(genericStore);

      final personTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Person',
      );
      final bookTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Book',
      );
      final summaryId = await objectStore.createProperty(
        objectTypeId: bookTypeId,
        name: 'Summary',
        type: ObjectPropertyType.text,
      );
      final authorId = await objectStore.createRelationProperty(
        objectTypeId: bookTypeId,
        name: 'Author',
        targetObjectTypeId: personTypeId,
        multiple: true,
      );
      final editorId = await objectStore.createRelationProperty(
        objectTypeId: bookTypeId,
        name: 'Editor',
        targetObjectTypeId: personTypeId,
        multiple: true,
      );
      final bookType = (await objectStore.getObjectType(bookTypeId))!;
      ObjectPropertyDefinition propertyById(int id) =>
          bookType.properties.firstWhere((property) => property.id == id);

      final indexedAuthorId = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'IndexedAuthorToken',
      );
      final storedOnlyAuthorId = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'StoredOnlyAuthorToken',
      );
      final validEditorId = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'ValidEditorToken',
      );
      final bookId = await objectStore.createObject(
        objectTypeId: bookTypeId,
        title: 'RelationConsistencyBook',
      );
      await objectStore.setPropertyValue(
        objectId: bookId,
        property: propertyById(summaryId),
        value: 'StablePropertyToken',
      );
      await objectStore.setRelation(
        objectId: bookId,
        property: propertyById(authorId),
        targetObjectIds: <int>[indexedAuthorId],
      );
      await objectStore.setRelation(
        objectId: bookId,
        property: propertyById(editorId),
        targetObjectIds: <int>[validEditorId],
      );

      await search.rebuildWorkspace(workspaceId);
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'indexedauthor',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'valideditor',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
      );

      // Keep the persisted Author value syntactically valid but change its
      // target without updating the normalized Relation edge. Relation #773
      // treats this serialized/index disagreement as an untrustworthy read.
      await genericStore.setValue(
        recordId: bookId,
        propertyId: authorId,
        value: <int>[storedOnlyAuthorId],
      );

      final edgesBeforeRefresh = await objectStore.outgoingRelations(bookId);
      expect(
        edgesBeforeRefresh
            .where((edge) => edge.propertyId == authorId)
            .map((edge) => edge.targetObjectId),
        <int>[indexedAuthorId],
        reason: 'the fixture must preserve the old normalized Author edge',
      );

      await search.refreshObject(bookId);

      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'indexedauthor',
        ))
            .map((hit) => hit.objectId),
        isNot(contains(bookId)),
        reason: 'focused refresh must remove the old untrustworthy edge label',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'storedonlyauthor',
        ))
            .map((hit) => hit.objectId),
        isNot(contains(bookId)),
        reason: 'Search must not infer a label from persisted ids alone',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'valideditor',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
        reason: 'a consistent Relation Property on the same Object stays searchable',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'stableproperty',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'relationconsistencybook',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
      );

      final persistedBook = (await objectStore.listObjects(bookTypeId))
          .singleWhere((object) => object.id == bookId);
      expect(
        persistedBook.values[authorId],
        <int>[storedOnlyAuthorId],
        reason: 'Search must not repair the persisted Relation value',
      );
      final edgesAfterRefresh = await objectStore.outgoingRelations(bookId);
      expect(
        edgesAfterRefresh
            .where((edge) => edge.propertyId == authorId)
            .map((edge) => edge.targetObjectId),
        <int>[indexedAuthorId],
        reason: 'Search must not repair normalized Relation edges',
      );

      await search.rebuildWorkspace(workspaceId);
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'indexedauthor',
        ))
            .map((hit) => hit.objectId),
        isNot(contains(bookId)),
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'storedonlyauthor',
        ))
            .map((hit) => hit.objectId),
        isNot(contains(bookId)),
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'valideditor',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
      );
    },
  );
}
