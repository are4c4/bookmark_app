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
    'malformed persisted Relation drops only that Property search labels',
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

      final staleTargetId = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'StaleRelationToken',
      );
      final validTargetId = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'ValidRelationToken',
      );
      final bookId = await objectStore.createObject(
        objectTypeId: bookTypeId,
        title: 'MalformedRelationBook',
      );
      await objectStore.setPropertyValue(
        objectId: bookId,
        property: propertyById(summaryId),
        value: 'StablePropertyToken',
      );
      await objectStore.setRelation(
        objectId: bookId,
        property: propertyById(authorId),
        targetObjectIds: <int>[staleTargetId],
      );
      await objectStore.setRelation(
        objectId: bookId,
        property: propertyById(editorId),
        targetObjectIds: <int>[validTargetId],
      );

      await search.rebuildWorkspace(workspaceId);
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'stalerelation',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'validrelation',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
      );

      // Corrupt only the persisted Author value while deliberately leaving its
      // normalized edge in place. Keep Editor in a supported legacy envelope
      // to prove valid compatibility shapes still contribute labels.
      await genericStore.setValue(
        recordId: bookId,
        propertyId: authorId,
        value: <dynamic>[staleTargetId, 'broken-id'],
      );
      await genericStore.setValue(
        recordId: bookId,
        propertyId: editorId,
        value: <String, dynamic>{
          'objectIds': <dynamic>['$validTargetId'],
        },
      );

      final edgesBeforeRefresh = await objectStore.outgoingRelations(bookId);
      expect(
        edgesBeforeRefresh.map((edge) => edge.targetObjectId).toSet(),
        <int>{staleTargetId, validTargetId},
        reason: 'the fixture must preserve both normalized edges',
      );

      await search.refreshObject(bookId);

      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'stalerelation',
        ))
            .map((hit) => hit.objectId),
        isNot(contains(bookId)),
        reason: 'focused refresh must remove the stale malformed Relation label',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'validrelation',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
        reason: 'a well-formed Relation Property on the same Object stays searchable',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'stableproperty',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
        reason: 'ordinary Property search must remain available',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'malformedrelationbook',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
        reason: 'Object identity search must remain available',
      );
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: '$staleTargetId',
        ),
        isEmpty,
        reason: 'Relation ids remain structural-only metadata',
      );

      final edgesAfterRefresh = await objectStore.outgoingRelations(bookId);
      expect(
        edgesAfterRefresh.map((edge) => edge.targetObjectId).toSet(),
        <int>{staleTargetId, validTargetId},
        reason: 'Search must not repair or mutate normalized Relation edges',
      );
      final persistedBook = (await objectStore.listObjects(bookTypeId))
          .singleWhere((object) => object.id == bookId);
      expect(
        persistedBook.values[authorId],
        <dynamic>[staleTargetId, 'broken-id'],
        reason: 'Search must leave malformed persisted Relation data untouched',
      );

      await search.rebuildWorkspace(workspaceId);
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'stalerelation',
        ))
            .map((hit) => hit.objectId),
        isNot(contains(bookId)),
        reason: 'workspace rebuild must also fail closed for malformed Relation data',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'validrelation',
        ))
            .map((hit) => hit.objectId),
        contains(bookId),
      );
    },
  );
}
