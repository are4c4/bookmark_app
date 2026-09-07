import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template View property names persist as stable Property id tokens', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final templateStore = ObjectTypeTemplateStore(genericStore);

    const template = ObjectTypeTemplate(
      key: 'view-property-config-regression',
      name: 'Research item',
      icon: '🧪',
      description: 'Stable View Property configuration regression',
      properties: [
        ObjectTypeTemplateProperty(name: 'Status', type: 'text'),
        ObjectTypeTemplateProperty(name: 'Due', type: 'date'),
        ObjectTypeTemplateProperty(name: 'Notes', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Focus',
          layoutType: 'table',
          visiblePropertyNames: ['Status', 'Due'],
          propertyOrderNames: ['Due', 'Status', 'Notes'],
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

    final view = (await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: 'custom:$objectTypeId',
    ))
        .single;

    expect(
      view.visibleProperties,
      ['p:${propertyIds['Status']}', 'p:${propertyIds['Due']}'],
    );
    expect(
      view.propertyOrder,
      [
        'p:${propertyIds['Due']}',
        'p:${propertyIds['Status']}',
        'p:${propertyIds['Notes']}',
      ],
    );
  });

  test('unknown template View Property rolls back the user-owned schema', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final templateStore = ObjectTypeTemplateStore(genericStore);

    const template = ObjectTypeTemplate(
      key: 'invalid-view-property-regression',
      name: 'Broken view config',
      icon: '⚠️',
      description: 'Unknown View Property must fail closed',
      properties: [
        ObjectTypeTemplateProperty(name: 'Known', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Broken',
          visiblePropertyNames: ['Missing'],
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
