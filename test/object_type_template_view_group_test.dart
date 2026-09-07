import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_group_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template View group resolves to the created Property id', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final templateStore = ObjectTypeTemplateStore(genericStore);

    const template = ObjectTypeTemplate(
      key: 'grouped-project-regression',
      name: 'Project',
      icon: '🚀',
      description: 'Template-local group Property regression',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Status',
          type: 'select',
          config: {
            'options': ['Todo', 'Doing', 'Done'],
          },
        ),
        ObjectTypeTemplateProperty(name: 'Notes', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Board',
          layoutType: 'board',
          group: ObjectTypeTemplateGroup(
            propertyName: 'Status',
            includeEmpty: false,
          ),
          settings: {'density': 'compact'},
        ),
      ],
    );

    final objectTypeId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: template,
    );
    final objectType = await objectStore.getObjectType(objectTypeId);
    final statusProperty = objectType!.properties.singleWhere(
      (property) => property.name == 'Status',
    );
    final view = (await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: 'custom:$objectTypeId',
    ))
        .single;

    expect(view.layoutType, 'board');
    final group = const DatabaseViewGroupAdapter().decode(view);
    expect(group, isNotNull);
    expect(group!.propertyId, statusProperty.id);
    expect(group.includeEmpty, isFalse);
    expect(view.settings['density'], 'compact');
  });

  test('unknown template View group fails before schema side effects', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final templateStore = ObjectTypeTemplateStore(genericStore);

    const template = ObjectTypeTemplate(
      key: 'unknown-group-regression',
      name: 'Broken group',
      icon: '⚠️',
      description: 'Unknown group Property must fail closed',
      properties: [
        ObjectTypeTemplateProperty(name: 'Known', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Board',
          layoutType: 'board',
          group: ObjectTypeTemplateGroup(propertyName: 'Missing'),
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

  test('symbolic template group rejects a raw groupRule collision', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final templateStore = ObjectTypeTemplateStore(genericStore);

    const template = ObjectTypeTemplate(
      key: 'duplicate-group-source-regression',
      name: 'Ambiguous group',
      icon: '⚠️',
      description: 'Group must have one template source of truth',
      properties: [
        ObjectTypeTemplateProperty(name: 'Status', type: 'select'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Board',
          group: ObjectTypeTemplateGroup(propertyName: 'Status'),
          settings: {
            DatabaseViewGroupAdapter.groupSettingsKey: {
              'propertyId': 999,
              'includeEmpty': true,
            },
          },
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
