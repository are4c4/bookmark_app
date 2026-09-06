import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Relation schema rename preserves a valid bidirectional pair', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: DatabaseViewStore(database),
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
    );

    final renamed = await service.renameProperty(
      objectTypeId: bookTypeId,
      propertyId: pair.sourceProperty.id,
      name: 'Writers',
    );

    expect(renamed.name, 'Writers');
    final refreshedPair = await bidirectionalStore.pairFor(renamed);
    expect(refreshedPair, isNotNull);
    expect(refreshedPair!.sourceProperty.name, 'Writers');
    expect(refreshedPair.inverseProperty.name, 'Books');
  });

  test('Relation schema rename fails closed on corrupt bidirectional metadata',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: DatabaseViewStore(database),
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
    final stored = (await genericStore.listProperties(bookTypeId))
        .singleWhere((property) => property.id == relationId);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: stored.id,
        databaseId: stored.databaseId,
        name: stored.name,
        type: stored.type,
        config: <String, dynamic>{
          ...stored.config,
          'bidirectional': true,
          'inversePropertyId': 999999,
          'pairRole': 'source',
        },
        sortOrder: stored.sortOrder,
      ),
    );

    await expectLater(
      service.renameProperty(
        objectTypeId: bookTypeId,
        propertyId: relationId,
        name: 'Writer',
      ),
      throwsStateError,
    );

    final property = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((candidate) => candidate.id == relationId);
    expect(property.name, 'Author');
    expect(property.config['inversePropertyId'], 999999);
  });
}
