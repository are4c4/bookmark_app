import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/app_shell_database_catalog_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'catalog lists empty and template-created Databases through one boundary',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceStore = WorkspaceStore(database);
      final workspaceId = await workspaceStore.initialize();
      final service = AppShellDatabaseCatalogService.fromWorkspaceStore(
        workspaceStore,
      );

      final emptyId = await service.createEmptyDatabase(
        workspaceId: workspaceId,
        name: '研究',
      );
      final project = ObjectTypeTemplateStore.templates.firstWhere(
        (template) => template.key == 'project',
      );
      final templateId = await service.createTemplateDatabase(
        workspaceId: workspaceId,
        template: project,
        name: '案件',
      );

      final catalog = await service.listDatabases(workspaceId: workspaceId);
      expect(
        catalog.map((database) => database.id),
        containsAll([emptyId, templateId]),
      );

      final store = GenericDatabaseStore(database);
      expect((await store.getDatabase(emptyId))?.name, '研究');
      final templated = await store.getDatabase(templateId);
      expect(templated?.name, '案件');
      expect(templated?.icon, '🚀');

      final views = await DatabaseViewStore(
        database,
      ).listViews(workspaceId: workspaceId, databaseKey: 'custom:$templateId');
      expect(views, hasLength(1));
      expect(views.single.layoutType, 'table');
    },
  );

  test(
    'a rebuilt catalog service stays bound to its new workspace store',
    () async {
      final firstDatabase = AppDatabase.forTesting(NativeDatabase.memory());
      final secondDatabase = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(firstDatabase.close);
      addTearDown(secondDatabase.close);

      final firstWorkspaceStore = WorkspaceStore(firstDatabase);
      final secondWorkspaceStore = WorkspaceStore(secondDatabase);
      final firstWorkspaceId = await firstWorkspaceStore.initialize();
      final secondWorkspaceId = await secondWorkspaceStore.initialize();

      final firstService = AppShellDatabaseCatalogService.fromWorkspaceStore(
        firstWorkspaceStore,
      );
      final secondService = AppShellDatabaseCatalogService.fromWorkspaceStore(
        secondWorkspaceStore,
      );

      await firstService.createEmptyDatabase(
        workspaceId: firstWorkspaceId,
        name: 'first only',
      );
      await secondService.createEmptyDatabase(
        workspaceId: secondWorkspaceId,
        name: 'second only',
      );

      expect(
        (await firstService.listDatabases(workspaceId: firstWorkspaceId))
            .map((database) => database.name),
        contains('first only'),
      );
      expect(
        (await secondService.listDatabases(workspaceId: secondWorkspaceId))
            .map((database) => database.name),
        contains('second only'),
      );
      expect(
        (await secondService.listDatabases(workspaceId: secondWorkspaceId))
            .map((database) => database.name),
        isNot(contains('first only')),
      );
    },
  );
}
