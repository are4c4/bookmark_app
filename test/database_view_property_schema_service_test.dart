import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_group_adapter.dart';
import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/data/database_view_query_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rename preserves Property identity, values, and View references', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final viewStore = DatabaseViewStore(database);
    final service = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: viewStore,
    );

    final booksId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Books',
    );
    final imagesId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Images',
    );
    final coverPropertyId = await objectStore.createRelationProperty(
      objectTypeId: booksId,
      name: 'Cover',
      targetObjectTypeId: imagesId,
      multiple: false,
    );
    final bookId = await objectStore.createObject(
      objectTypeId: booksId,
      title: 'Book A',
    );
    final imageId = await objectStore.createObject(
      objectTypeId: imagesId,
      title: 'Image A',
    );
    final coverProperty = (await objectStore.getObjectType(booksId))!
        .properties
        .firstWhere((property) => property.id == coverPropertyId);
    await objectStore.setRelation(
      objectId: bookId,
      property: coverProperty,
      targetObjectIds: [imageId],
    );

    final definition = DatabaseDefinition(
      key: 'custom:$booksId',
      label: 'Books',
      icon: Icons.menu_book_outlined,
      properties: [
        DatabasePropertyDefinition(
          key: 'p:$coverPropertyId',
          label: 'Cover',
          type: DatabasePropertyType.relation,
          icon: Icons.swap_horiz,
        ),
      ],
      defaultLayout: 'gallery',
    );
    final viewId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Gallery',
      visibleProperties: ['p:$coverPropertyId'],
      propertyOrder: ['p:$coverPropertyId'],
    );
    var view = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .firstWhere((candidate) => candidate.id == viewId);
    view = const DatabaseViewQueryAdapter().encode(
      view,
      filters: [
        ObjectFilterRule(
          propertyId: coverPropertyId,
          operator: ObjectFilterOperator.isNotEmpty,
        ),
      ],
      sorts: [
        ObjectSortRule(
          propertyId: coverPropertyId,
          direction: ObjectSortDirection.ascending,
        ),
      ],
    );
    view = const DatabaseViewGroupAdapter().encode(
      view,
      group: ObjectGroupRule(propertyId: coverPropertyId),
    );
    view = const DatabaseViewGalleryAdapter().encodeCoverSource(
      view,
      source: GalleryCoverSource.imageRelation(coverPropertyId),
    );
    await viewStore.updateView(view);

    final renamed = await service.renameProperty(
      objectTypeId: booksId,
      propertyId: coverPropertyId,
      name: '  Primary Cover  ',
    );

    expect(renamed.id, coverPropertyId);
    expect(renamed.name, 'Primary Cover');
    expect(renamed.targetObjectTypeId, imagesId);
    expect(renamed.allowsMultipleRelations, isFalse);

    final book = (await objectStore.listObjects(booksId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[coverPropertyId]).objectIds,
      [imageId],
    );

    final persisted = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .single;
    expect(persisted.visibleProperties, ['p:$coverPropertyId']);
    expect(persisted.propertyOrder, ['p:$coverPropertyId']);
    expect(
      const DatabaseViewQueryAdapter().decode(persisted).filters.single.propertyId,
      coverPropertyId,
    );
    expect(
      const DatabaseViewQueryAdapter().decode(persisted).sorts.single.propertyId,
      coverPropertyId,
    );
    expect(
      const DatabaseViewGroupAdapter().decode(persisted)!.propertyId,
      coverPropertyId,
    );
    expect(
      const DatabaseViewGalleryAdapter()
          .decodeCoverSource(persisted)
          .relationPropertyId,
      coverPropertyId,
    );
  });

  test('delete impact reports stored values and every View reference kind', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final viewStore = DatabaseViewStore(database);
    final service = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: viewStore,
    );

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Plant',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Image',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Images',
      targetObjectTypeId: targetTypeId,
      multiple: true,
    );
    final sourceA = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Plant A',
    );
    await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Plant B',
    );
    final target = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Image A',
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .firstWhere((candidate) => candidate.id == propertyId);
    await objectStore.setRelation(
      objectId: sourceA,
      property: property,
      targetObjectIds: [target],
    );

    final definition = DatabaseDefinition(
      key: 'custom:$sourceTypeId',
      label: 'Plants',
      icon: Icons.local_florist_outlined,
      properties: [
        DatabasePropertyDefinition(
          key: 'p:$propertyId',
          label: 'Images',
          type: DatabasePropertyType.relation,
          icon: Icons.image_outlined,
        ),
      ],
      defaultLayout: 'gallery',
    );
    await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Unrelated',
      visibleProperties: const [],
      propertyOrder: const [],
    );
    final referencedId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Referenced',
      visibleProperties: ['p:$propertyId'],
      propertyOrder: ['p:$propertyId'],
    );
    final views = await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    var referenced = views.firstWhere((view) => view.id == referencedId);
    referenced = const DatabaseViewQueryAdapter().encode(
      referenced,
      filters: [
        ObjectFilterRule(
          propertyId: propertyId,
          operator: ObjectFilterOperator.isNotEmpty,
        ),
      ],
      sorts: [
        ObjectSortRule(
          propertyId: propertyId,
          direction: ObjectSortDirection.descending,
        ),
      ],
    );
    referenced = const DatabaseViewGroupAdapter().encode(
      referenced,
      group: ObjectGroupRule(propertyId: propertyId),
    );
    referenced = const DatabaseViewGalleryAdapter().encodeCoverSource(
      referenced,
      source: GalleryCoverSource.imageRelation(propertyId),
    );
    await viewStore.updateView(referenced);

    final impact = await service.inspectDelete(
      objectTypeId: sourceTypeId,
      propertyId: propertyId,
    );

    expect(impact.property.id, propertyId);
    expect(impact.objectsWithStoredValue, 1);
    expect(impact.hasStoredValues, isTrue);
    expect(impact.viewReferences, hasLength(1));
    final reference = impact.viewReferences.single;
    expect(reference.viewId, referencedId);
    expect(reference.viewName, 'Referenced');
    expect(
      reference.kinds,
      {
        DatabaseViewPropertyReferenceKind.visible,
        DatabaseViewPropertyReferenceKind.order,
        DatabaseViewPropertyReferenceKind.filter,
        DatabaseViewPropertyReferenceKind.sort,
        DatabaseViewPropertyReferenceKind.group,
        DatabaseViewPropertyReferenceKind.galleryCover,
      },
    );
  });

  test('system ObjectType properties cannot be renamed or inspected for delete',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final viewStore = DatabaseViewStore(database);
    final service = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: viewStore,
    );

    final systemType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'test-primitive',
      name: 'Primitive',
      icon: '◆',
    );
    final property = await systemObjects.ensureProperty(
      objectTypeId: systemType.id,
      name: 'Native value',
      type: ObjectPropertyType.text,
    );

    await expectLater(
      service.renameProperty(
        objectTypeId: systemType.id,
        propertyId: property.id,
        name: 'Changed',
      ),
      throwsStateError,
    );
    await expectLater(
      service.inspectDelete(
        objectTypeId: systemType.id,
        propertyId: property.id,
      ),
      throwsStateError,
    );
  });
}
