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

RelationMutationService _mutations(
  GenericDatabaseStore genericStore,
  ObjectStore objectStore,
  BidirectionalRelationStore bidirectionalStore,
) =>
    RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );

RelationSchemaEvolutionService _schemaEvolution(
  GenericDatabaseStore genericStore,
  ObjectStore objectStore,
  RelationMutationService mutations,
) =>
    RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
      relationMutations: mutations,
    );

void main() {
  test('target change fails closed and preserves schema values and indexes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = _mutations(
      genericStore,
      objectStore,
      bidirectionalStore,
    );
    final schemaEvolution = _schemaEvolution(
      genericStore,
      objectStore,
      mutations,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final companyTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Company',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
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

    await expectLater(
      schemaEvolution.updateRelationSchema(
        property: property,
        targetObjectTypeId: companyTypeId,
        multiple: true,
      ),
      throwsStateError,
    );

    final refreshedProperty = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((item) => item.id == relationId);
    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(refreshedProperty.targetObjectTypeId, personTypeId);
    expect(
      ObjectRelationValue.fromJson(book.values[relationId]).objectIds,
      <int>[personId],
    );
    expect(
      (await objectStore.outgoingRelations(bookId))
          .where((edge) => edge.propertyId == relationId)
          .map((edge) => edge.targetObjectId),
      <int>[personId],
    );
    expect(
      (await objectStore.backlinks(personId)).map((edge) => edge.sourceObjectId),
      contains(bookId),
    );
  });

  test('target change succeeds when every existing Relation value is empty', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = _mutations(
      genericStore,
      objectStore,
      bidirectionalStore,
    );
    final schemaEvolution = _schemaEvolution(
      genericStore,
      objectStore,
      mutations,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final companyTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Company',
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
    await objectStore.createObject(objectTypeId: bookTypeId, title: 'Book');

    final updated = await schemaEvolution.updateRelationSchema(
      property: property,
      targetObjectTypeId: companyTypeId,
      multiple: false,
    );

    expect(updated.targetObjectTypeId, companyTypeId);
    expect(updated.allowsMultipleRelations, isFalse);
    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(ObjectRelationValue.fromJson(book.values[relationId]).isEmpty, isTrue);
  });

  test('multi to single requires explicit choice and only drops chosen conflicts', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = _mutations(
      genericStore,
      objectStore,
      bidirectionalStore,
    );
    final schemaEvolution = _schemaEvolution(
      genericStore,
      objectStore,
      mutations,
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
      name: 'Authors',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((item) => item.id == relationId);
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final firstPersonId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'First',
    );
    final secondPersonId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Second',
    );
    await mutations.setRelation(
      objectId: bookId,
      property: property,
      targetObjectIds: <int>[firstPersonId, secondPersonId],
    );

    final impact = await schemaEvolution.inspectChange(
      property: property,
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    expect(impact.requiresMultiToSingleChoice, isTrue);
    expect(
      impact.multiToSingleConflicts[bookId],
      <int>[firstPersonId, secondPersonId],
    );

    await expectLater(
      schemaEvolution.updateRelationSchema(
        property: property,
        targetObjectTypeId: personTypeId,
        multiple: false,
      ),
      throwsStateError,
    );
    expect(
      (await objectStore.getObjectType(bookTypeId))!
          .properties
          .singleWhere((item) => item.id == relationId)
          .allowsMultipleRelations,
      isTrue,
    );

    final updated = await schemaEvolution.updateRelationSchema(
      property: property,
      targetObjectTypeId: personTypeId,
      multiple: false,
      multiToSingleSelections: <int, int>{bookId: secondPersonId},
    );

    expect(updated.allowsMultipleRelations, isFalse);
    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[relationId]).objectIds,
      <int>[secondPersonId],
    );
    expect(await objectStore.backlinks(firstPersonId), isEmpty);
    expect(
      (await objectStore.backlinks(secondPersonId))
          .map((edge) => edge.sourceObjectId),
      contains(bookId),
    );
  });

  test('single to multi preserves the stored value and relation edge', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = _mutations(
      genericStore,
      objectStore,
      bidirectionalStore,
    );
    final schemaEvolution = _schemaEvolution(
      genericStore,
      objectStore,
      mutations,
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
    final rawBefore = (await genericStore.listRecords(bookTypeId))
        .single
        .values[relationId];
    expect(rawBefore, personId);

    final updated = await schemaEvolution.updateRelationSchema(
      property: property,
      targetObjectTypeId: personTypeId,
      multiple: true,
    );

    final rawAfter = (await genericStore.listRecords(bookTypeId))
        .single
        .values[relationId];
    expect(updated.allowsMultipleRelations, isTrue);
    expect(rawAfter, rawBefore);
    expect(
      (await objectStore.outgoingRelations(bookId))
          .where((edge) => edge.propertyId == relationId)
          .map((edge) => edge.targetObjectId),
      <int>[personId],
    );
  });

  test('bidirectional target change fails without breaking pair metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = _mutations(
      genericStore,
      objectStore,
      bidirectionalStore,
    );
    final schemaEvolution = _schemaEvolution(
      genericStore,
      objectStore,
      mutations,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final companyTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Company',
    );
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );

    await expectLater(
      schemaEvolution.updateRelationSchema(
        property: pair.sourceProperty,
        targetObjectTypeId: companyTypeId,
        multiple: true,
      ),
      throwsStateError,
    );

    final source = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((item) => item.id == pair.sourceProperty.id);
    expect(source.targetObjectTypeId, personTypeId);
    expect(await bidirectionalStore.pairFor(source), isNotNull);
  });

  test('multi to single reduction preserves bidirectional inverse integrity', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = _mutations(
      genericStore,
      objectStore,
      bidirectionalStore,
    );
    final schemaEvolution = _schemaEvolution(
      genericStore,
      objectStore,
      mutations,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
      sourceMultiple: true,
      inverseMultiple: true,
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final firstPersonId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'First',
    );
    final secondPersonId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Second',
    );
    await mutations.setRelation(
      objectId: bookId,
      property: pair.sourceProperty,
      targetObjectIds: <int>[firstPersonId, secondPersonId],
    );

    final updated = await schemaEvolution.updateRelationSchema(
      property: pair.sourceProperty,
      targetObjectTypeId: personTypeId,
      multiple: false,
      multiToSingleSelections: <int, int>{bookId: secondPersonId},
    );

    expect(updated.allowsMultipleRelations, isFalse);
    final people = await objectStore.listObjects(personTypeId);
    final first = people.singleWhere((item) => item.id == firstPersonId);
    final second = people.singleWhere((item) => item.id == secondPersonId);
    expect(
      ObjectRelationValue.fromJson(
        first.values[pair.inverseProperty.id],
      ).objectIds,
      isEmpty,
    );
    expect(
      ObjectRelationValue.fromJson(
        second.values[pair.inverseProperty.id],
      ).objectIds,
      <int>[bookId],
    );
    expect(await bidirectionalStore.pairFor(updated), isNotNull);
  });
}
