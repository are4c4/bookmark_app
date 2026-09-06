import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_schema_evolution_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema change fails closed when the Relation edge index is stale', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );
    final schemaEvolution = RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
      relationMutations: mutations,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((item) => item.id == relationId);
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );
    await mutations.setRelation(
      objectId: bookId,
      property: property,
      targetObjectIds: <int>[personId],
    );
    await database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      <Object>[bookId, relationId],
    );

    await expectLater(
      schemaEvolution.updateRelationSchema(
        property: property,
        targetObjectTypeId: personTypeId,
        multiple: true,
      ),
      throwsStateError,
    );

    final refreshed = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((item) => item.id == relationId);
    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(refreshed.allowsMultipleRelations, isFalse);
    expect(
      ObjectRelationValue.fromJson(book.values[relationId]).objectIds,
      <int>[personId],
    );
    expect(await objectStore.outgoingRelations(bookId), isEmpty);
  });

  test('schema change fails closed when a persisted target Object is missing', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );
    final schemaEvolution = RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
      relationMutations: mutations,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((item) => item.id == relationId);
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );
    await mutations.setRelation(
      objectId: bookId,
      property: property,
      targetObjectIds: <int>[personId],
    );

    // Simulate legacy/corrupt low-level deletion that bypassed Relation-safe
    // detach. The persisted Property value remains and must not be guessed away
    // by a later schema edit.
    await objectStore.deleteObject(personId);

    await expectLater(
      schemaEvolution.updateRelationSchema(
        property: property,
        targetObjectTypeId: personTypeId,
        multiple: true,
      ),
      throwsStateError,
    );

    final refreshed = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((item) => item.id == relationId);
    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(refreshed.allowsMultipleRelations, isFalse);
    expect(
      ObjectRelationValue.fromJson(book.values[relationId]).objectIds,
      <int>[personId],
    );
  });
}
