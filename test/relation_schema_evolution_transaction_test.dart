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
  test('failed schema write rolls back prior multi to single Relation reduction', () async {
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

    await database.customStatement('''
      CREATE TRIGGER fail_relation_schema_update
      BEFORE UPDATE OF config_json ON generic_properties
      WHEN OLD.id = $relationId
      BEGIN
        SELECT RAISE(ABORT, 'forced relation schema update failure');
      END
    ''');

    await expectLater(
      schemaEvolution.updateRelationSchema(
        property: property,
        targetObjectTypeId: personTypeId,
        multiple: false,
        multiToSingleSelections: <int, int>{bookId: secondPersonId},
      ),
      throwsA(anything),
    );

    final refreshed = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((item) => item.id == relationId);
    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(refreshed.allowsMultipleRelations, isTrue);
    expect(
      ObjectRelationValue.fromJson(book.values[relationId]).objectIds,
      <int>[firstPersonId, secondPersonId],
    );
    expect(
      (await objectStore.outgoingRelations(bookId))
          .where((edge) => edge.propertyId == relationId)
          .map((edge) => edge.targetObjectId)
          .toList(growable: false),
      <int>[firstPersonId, secondPersonId],
    );
  });
}
