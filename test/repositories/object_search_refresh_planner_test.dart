import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_search_refresh_planner.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target label change refreshes target and all canonical backlink sources',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final planner = ObjectSearchRefreshPlanner(objectStore);

    final personType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final bookType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final authorPropertyId = await objectStore.createRelationProperty(
      objectTypeId: bookType,
      name: 'Author',
      targetObjectTypeId: personType,
      multiple: false,
    );
    final bookTypeDefinition = (await objectStore.getObjectType(bookType))!;
    final authorProperty = bookTypeDefinition.properties.firstWhere(
      (property) => property.id == authorPropertyId,
    );

    final person = await objectStore.createObject(
      objectTypeId: personType,
      title: 'Target Person',
    );
    final firstBook = await objectStore.createObject(
      objectTypeId: bookType,
      title: 'First Book',
    );
    final secondBook = await objectStore.createObject(
      objectTypeId: bookType,
      title: 'Second Book',
    );
    await objectStore.setPropertyValue(
      objectId: secondBook,
      property: authorProperty,
      value: ObjectRelationValue.single(person),
    );
    await objectStore.setPropertyValue(
      objectId: firstBook,
      property: authorProperty,
      value: ObjectRelationValue.single(person),
    );

    expect(
      await planner.forObjectLabelChange(person),
      <int>[person, firstBook, secondBook]..sortRange(1, 3),
    );
    expect(await planner.forObjectLabelChange(firstBook), <int>[firstBook]);
  });

  test('missing or deleted Object still plans its own stale search row removal',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final planner = ObjectSearchRefreshPlanner(
      ObjectStore(GenericDatabaseStore(database)),
    );

    expect(await planner.forObjectLabelChange(999999), <int>[999999]);
  });
}
