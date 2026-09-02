import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('page services share canonical collection creation and Relation paths',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Reading Database',
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Related book',
      targetObjectTypeId: bookTypeId,
      multiple: true,
    );
    final existingId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Serre',
    );

    await services.collectionConfig.save(
      databaseId: databaseId,
      workspaceId: workspaceId,
      targetObjectTypeId: bookTypeId,
    );

    final page = await services.loader.load(databaseId);
    expect(page?.database.id, databaseId);
    expect(page?.objectType.id, bookTypeId);
    expect(page?.objects.map((object) => object.id), <int>[existingId]);

    final createdId = await services.creator.create(
      databaseId: databaseId,
      title: 'Local Fields',
    );
    final created = (await objectStore.listObjects(bookTypeId))
        .singleWhere((object) => object.id == createdId);
    expect(created.objectTypeId, bookTypeId);

    final bookType = (await objectStore.getObjectType(bookTypeId))!;
    final relation = bookType.properties
        .singleWhere((property) => property.id == relationId);
    final selection = await services.relationEditor.load(
      workspaceId: workspaceId,
      sourceObjectId: createdId,
      property: relation,
    );
    await services.relationEditor.save(
      context: selection,
      selectedObjectIds: <int>[existingId],
    );

    final updated = (await objectStore.listObjects(bookTypeId))
        .singleWhere((object) => object.id == createdId);
    expect(
      ObjectRelationValue.fromJson(updated.valueFor(relationId)).objectIds,
      <int>[existingId],
    );
  });
}
