import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_query_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template View query rules resolve Property names to created ids', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final templateStore = ObjectTypeTemplateStore(genericStore);

    const template = ObjectTypeTemplate(
      key: 'query-property-ref-regression',
      name: 'Research item',
      icon: '🧪',
      description: 'Stable template query Property refs',
      properties: [
        ObjectTypeTemplateProperty(name: 'Status', type: 'text'),
        ObjectTypeTemplateProperty(name: 'Due', type: 'date'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Focus',
          filters: {
            'query': 'needle',
            'propertyRules': [
              {
                'propertyId': null,
                'operator': 'contains',
                'value': 'title',
              },
            ],
          },
          sorts: [
            {'propertyId': null, 'direction': 'ascending'},
          ],
          propertyFilters: [
            ObjectTypeTemplateFilter(
              propertyName: 'Status',
              operator: ObjectFilterOperator.equals,
              value: 'active',
            ),
          ],
          propertySorts: [
            ObjectTypeTemplateSort(
              propertyName: 'Due',
              direction: ObjectSortDirection.descending,
            ),
          ],
        ),
      ],
    );

    final objectTypeId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: template,
    );
    final objectType = await objectStore.getObjectType(objectTypeId);
    final propertyIds = <String, int>{
      for (final property in objectType!.properties) property.name: property.id,
    };
    final persisted = (await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: 'custom:$objectTypeId',
    ))
        .single;
    final query = const DatabaseViewQueryAdapter().decode(persisted);

    expect(query.searchQuery, 'needle');
    expect(query.filters, hasLength(2));
    expect(query.filters.first.propertyId, isNull);
    expect(query.filters.last.propertyId, propertyIds['Status']);
    expect(query.filters.last.operator, ObjectFilterOperator.equals);
    expect(query.filters.last.value, 'active');
    expect(query.sorts, hasLength(2));
    expect(query.sorts.first.propertyId, isNull);
    expect(query.sorts.last.propertyId, propertyIds['Due']);
    expect(query.sorts.last.direction, ObjectSortDirection.descending);
  });

  test('unknown template query Property rolls back user-owned schema', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final templateStore = ObjectTypeTemplateStore(genericStore);

    const template = ObjectTypeTemplate(
      key: 'invalid-query-property-ref-regression',
      name: 'Broken query config',
      icon: '⚠️',
      description: 'Unknown query Property must fail closed',
      properties: [
        ObjectTypeTemplateProperty(name: 'Known', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Broken',
          propertyFilters: [
            ObjectTypeTemplateFilter(
              propertyName: 'Missing',
              operator: ObjectFilterOperator.equals,
              value: 'x',
            ),
          ],
        ),
      ],
    );

    final beforeIds = (await genericStore.listAllDatabases(workspaceId))
        .map((database) => database.id)
        .toList(growable: false);
    await expectLater(
      templateStore.createFromTemplate(
        workspaceId: workspaceId,
        template: template,
      ),
      throwsStateError,
    );
    final afterIds = (await genericStore.listAllDatabases(workspaceId))
        .map((database) => database.id)
        .toList(growable: false);

    expect(afterIds, beforeIds);
  });
}
