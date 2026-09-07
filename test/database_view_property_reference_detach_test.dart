import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_group_adapter.dart';
import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/data/database_view_query_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit detach removes only the selected Property from View config',
      () async {
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

    final imageTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Image target',
    );
    final plantTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Plant',
    );
    final photoPropertyId = await objectStore.createRelationProperty(
      objectTypeId: plantTypeId,
      name: 'Photo',
      targetObjectTypeId: imageTypeId,
      multiple: false,
    );
    final ratingPropertyId = await objectStore.createProperty(
      objectTypeId: plantTypeId,
      name: 'Rating',
      type: ObjectPropertyType.number,
    );
    final plantId = await objectStore.createObject(
      objectTypeId: plantTypeId,
      title: 'Monstera',
    );
    final imageId = await objectStore.createObject(
      objectTypeId: imageTypeId,
      title: 'Photo A',
    );
    final photoProperty = (await objectStore.getObjectType(plantTypeId))!
        .properties
        .firstWhere((property) => property.id == photoPropertyId);
    await objectStore.setRelation(
      objectId: plantId,
      property: photoProperty,
      targetObjectIds: [imageId],
    );

    final definition = DatabaseDefinition(
      key: 'custom:$plantTypeId',
      label: 'Plants',
      icon: Icons.local_florist_outlined,
      properties: [
        DatabasePropertyDefinition(
          key: 'p:$photoPropertyId',
          label: 'Photo',
          type: DatabasePropertyType.relation,
          icon: Icons.image_outlined,
        ),
        DatabasePropertyDefinition(
          key: 'p:$ratingPropertyId',
          label: 'Rating',
          type: DatabasePropertyType.number,
          icon: Icons.numbers,
        ),
      ],
      defaultLayout: 'gallery',
    );
    final referencedViewId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Referenced',
      layoutType: 'gallery',
      visibleProperties: [
        'p:$photoPropertyId',
        'p:$ratingPropertyId',
      ],
      propertyOrder: [
        'p:$photoPropertyId',
        'p:$ratingPropertyId',
      ],
      settings: const {'openMode': 'sidePeek'},
    );
    final untouchedViewId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Untouched',
      layoutType: 'list',
      visibleProperties: ['p:$ratingPropertyId'],
      propertyOrder: ['p:$ratingPropertyId'],
      settings: const {'futureSetting': true},
    );

    var referenced = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .firstWhere((view) => view.id == referencedViewId);
    referenced = const DatabaseViewQueryAdapter().encode(
      referenced,
      filters: [
        ObjectFilterRule(
          propertyId: photoPropertyId,
          operator: ObjectFilterOperator.isNotEmpty,
        ),
        ObjectFilterRule(
          propertyId: ratingPropertyId,
          operator: ObjectFilterOperator.isNotEmpty,
        ),
      ],
      sorts: [
        ObjectSortRule(
          propertyId: photoPropertyId,
          direction: ObjectSortDirection.ascending,
        ),
        ObjectSortRule(
          propertyId: ratingPropertyId,
          direction: ObjectSortDirection.descending,
        ),
      ],
    );
    referenced = referenced.copyWith(
      filters: {
        ...referenced.filters,
        'propertyRules': [
          ...(referenced.filters['propertyRules'] as List),
          const {'futureRule': true},
        ],
      },
      sorts: [
        ...referenced.sorts,
        const {'futureSort': true},
      ],
    );
    referenced = const DatabaseViewGroupAdapter().encode(
      referenced,
      group: ObjectGroupRule(propertyId: photoPropertyId),
    );
    referenced = const DatabaseViewGalleryAdapter().encodeCoverSource(
      referenced,
      source: GalleryCoverSource.imageRelation(photoPropertyId),
    );
    await viewStore.updateView(referenced);

    final changed = await service.detachViewReferences(
      objectTypeId: plantTypeId,
      propertyId: photoPropertyId,
    );

    expect(changed, 1);
    final views = await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    final persisted = views.firstWhere((view) => view.id == referencedViewId);
    expect(persisted.visibleProperties, ['p:$ratingPropertyId']);
    expect(persisted.propertyOrder, ['p:$ratingPropertyId']);

    final query = const DatabaseViewQueryAdapter().decode(persisted);
    expect(query.filters, hasLength(1));
    expect(query.filters.single.propertyId, ratingPropertyId);
    expect(query.sorts, hasLength(1));
    expect(query.sorts.single.propertyId, ratingPropertyId);
    expect(
      (persisted.filters['propertyRules'] as List).last,
      const {'futureRule': true},
    );
    expect(persisted.sorts.last, const {'futureSort': true});
    expect(const DatabaseViewGroupAdapter().decode(persisted), isNull);
    expect(
      const DatabaseViewGalleryAdapter().decodeCoverSource(persisted),
      const GalleryCoverSource.none(),
    );
    expect(persisted.settings['openMode'], 'sidePeek');

    final untouched = views.firstWhere((view) => view.id == untouchedViewId);
    expect(untouched.visibleProperties, ['p:$ratingPropertyId']);
    expect(untouched.propertyOrder, ['p:$ratingPropertyId']);
    expect(untouched.settings['futureSetting'], isTrue);

    final type = await objectStore.getObjectType(plantTypeId);
    expect(
      type!.properties.any((property) => property.id == photoPropertyId),
      isTrue,
    );
    final plant = (await objectStore.listObjects(plantTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(plant.values[photoPropertyId]).objectIds,
      [imageId],
    );

    final impact = await service.inspectDelete(
      objectTypeId: plantTypeId,
      propertyId: photoPropertyId,
    );
    expect(impact.viewReferences, isEmpty);
    expect(impact.objectsWithStoredValue, 1);
  });
}
