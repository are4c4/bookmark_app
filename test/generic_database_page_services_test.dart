import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

  test('page services expose Relation-safe Object deletion for real hosts',
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

    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final authorPropertyId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Author',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final bookType = (await objectStore.getObjectType(bookTypeId))!;
    final authorProperty = bookType.properties
        .singleWhere((property) => property.id == authorPropertyId);
    await services.relationMutations.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: <int>[personId],
    );

    await services.relationMutations.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: personTypeId,
      objectId: personId,
    );

    expect(await objectStore.listObjects(personTypeId), isEmpty);
    final survivingBook = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(
        survivingBook.valueFor(authorPropertyId),
      ).objectIds,
      isEmpty,
    );
  });

  test('page services expose canonical Object open-mode resolution', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    await ObjectTypeDefaultsStore(genericStore).write(
      objectTypeId: objectTypeId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.centerPeek),
    );

    const definition = DatabaseDefinition(
      key: 'custom:notes',
      label: 'Notes',
      icon: Icons.note_outlined,
      properties: <DatabasePropertyDefinition>[],
      defaultLayout: 'list',
      supportedLayouts: <String>['list'],
    );
    final viewStore = DatabaseViewStore(database);
    final viewId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'All',
      settings: const <String, dynamic>{'openMode': 'fullPage'},
    );
    final view = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .singleWhere((candidate) => candidate.id == viewId);

    expect(
      await services.openPresentation.resolve(
        view: view,
        objectTypeId: objectTypeId,
      ),
      ObjectOpenMode.fullPage,
    );
    expect(
      await services.openPresentation.resolve(
        view: view.copyWith(settings: const <String, dynamic>{}),
        objectTypeId: objectTypeId,
      ),
      ObjectOpenMode.centerPeek,
    );
  });
}
