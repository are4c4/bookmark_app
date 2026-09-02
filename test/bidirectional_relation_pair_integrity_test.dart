import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pairFor rejects inverse metadata that is no longer bidirectional', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final relations = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final pair = await relations.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );

    final inverse = (await genericStore.listProperties(personTypeId))
        .singleWhere((property) => property.id == pair.inverseProperty.id);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: inverse.id,
        databaseId: inverse.databaseId,
        name: inverse.name,
        type: inverse.type,
        sortOrder: inverse.sortOrder,
        config: <String, dynamic>{
          ...inverse.config,
          'bidirectional': false,
        },
      ),
    );

    expect(await relations.pairFor(pair.sourceProperty), isNull);
  });

  test('pairFor rejects an inverse relation targeting the wrong ObjectType', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final relations = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final pair = await relations.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );

    final inverse = (await genericStore.listProperties(personTypeId))
        .singleWhere((property) => property.id == pair.inverseProperty.id);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: inverse.id,
        databaseId: inverse.databaseId,
        name: inverse.name,
        type: inverse.type,
        sortOrder: inverse.sortOrder,
        config: <String, dynamic>{
          ...inverse.config,
          'targetObjectTypeId': personTypeId,
        },
      ),
    );

    expect(await relations.pairFor(pair.sourceProperty), isNull);
  });
}
