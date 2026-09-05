part of 'app_database.dart';

extension AppDatabaseMigrationSteps on AppDatabase {
  Future<void> migrateToV14(Migrator migrator) async {
    await migrator.addColumn(
      savedViews,
      savedViews.includeDescendants,
    );
    await migrator.addColumn(savedViews, savedViews.personFilterId);
    await migrator.addColumn(savedViews, savedViews.photoFilterId);
  }

  Future<void> migrateToV15(Migrator migrator) async {
    final existing = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final tableNames = existing.map((row) => row.read<String>('name')).toSet();

    if (!tableNames.contains('person_groups')) {
      await migrator.createTable(personGroups);
    }
    if (!tableNames.contains('person_group_members')) {
      await migrator.createTable(personGroupMembers);
    }
    if (!tableNames.contains('database_views')) {
      await migrator.createTable(databaseViews);
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS person_group_members_person_idx '
      'ON person_group_members(person_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS database_views_scope_idx '
      'ON database_views(workspace_id, database_key, sort_order, id)',
    );
  }

  Future<void> migrateToV16(Migrator migrator) async {
    final existing = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final tableNames = existing.map((row) => row.read<String>('name')).toSet();

    if (!tableNames.contains('generic_databases')) {
      await migrator.createTable(genericDatabases);
    }
    if (!tableNames.contains('generic_properties')) {
      await migrator.createTable(genericProperties);
    }
    if (!tableNames.contains('generic_records')) {
      await migrator.createTable(genericRecords);
    }
    if (!tableNames.contains('generic_values')) {
      await migrator.createTable(genericValues);
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS generic_databases_workspace_idx '
      'ON generic_databases(workspace_id, sort_order, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS generic_properties_database_idx '
      'ON generic_properties(database_id, sort_order, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS generic_records_database_idx '
      'ON generic_records(database_id, updated_at DESC, id DESC)',
    );
  }
}
