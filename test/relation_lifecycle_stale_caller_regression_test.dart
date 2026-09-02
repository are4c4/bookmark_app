import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late BidirectionalRelationStore bidirectionalStore;
  late RelationMutationService mutations;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );
    workspaceId = await WorkspaceStore(database).initialize();
  });

  tearDown(() => database.close());

  Future<({
    int bookTypeId,
    int personTypeId,
    BidirectionalRelationPair pair,
  })> createPair() async {
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
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    return (
      bookTypeId: bookTypeId,
      personTypeId: personTypeId,
      pair: pair,
    );
  }

  ObjectPropertyDefinition staleCopy(ObjectPropertyDefinition property) =>
      ObjectPropertyDefinition(
        id: property.id,
        objectTypeId: property.objectTypeId,
        name: 'Stale name',
        type: property.type,
        sortOrder: property.sortOrder,
        config: <String, dynamic>{
          ...property.config,
          'bidirectional': false,
          'inversePropertyId': null,
        },
      );

  test('stale caller metadata cannot prevent pair-aware rename', () async {
    final setup = await createPair();
    final stale = staleCopy(setup.pair.sourceProperty);

    final renamed = await mutations.renameRelationProperty(
      property: stale,
      name: 'Writer',
      inverseName: 'Written books',
    );

    expect(renamed.id, setup.pair.sourceProperty.id);
    expect(renamed.name, 'Writer');
    expect(
      (await objectStore.getObjectType(setup.bookTypeId))!.properties.single.name,
      'Writer',
    );
    expect(
      (await objectStore.getObjectType(setup.personTypeId))!.properties.single.name,
      'Written books',
    );
  });

  test('stale caller metadata cannot orphan an inverse Property on delete', () async {
    final setup = await createPair();
    final stale = staleCopy(setup.pair.sourceProperty);

    await mutations.deleteRelationProperty(stale);

    expect(
      (await objectStore.getObjectType(setup.bookTypeId))!.properties,
      isEmpty,
    );
    expect(
      (await objectStore.getObjectType(setup.personTypeId))!.properties,
      isEmpty,
    );
  });
}
