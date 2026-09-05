from pathlib import Path

app_path = Path('lib/data/app_database.dart')
app = app_path.read_text()
old = "          if (from < 8) await m.addColumn(savedViews, savedViews.visibleProperties);\n"
new = "          if (from < 8) await migrateToV8(m);\n"
if app.count(old) != 1:
    raise SystemExit(f'expected exactly one inline v8 migration, found {app.count(old)}')
app_path.write_text(app.replace(old, new, 1))

migration_path = Path('lib/data/app_database_migrations.dart')
migrations = migration_path.read_text()
anchor = "extension AppDatabaseMigrationSteps on AppDatabase {\n"
helper = """extension AppDatabaseMigrationSteps on AppDatabase {
  Future<void> migrateToV8(Migrator migrator) async {
    await migrator.addColumn(savedViews, savedViews.visibleProperties);
  }

"""
if migrations.count(anchor) != 1:
    raise SystemExit(f'expected exactly one migration extension anchor, found {migrations.count(anchor)}')
if 'Future<void> migrateToV8(' in migrations:
    raise SystemExit('migrateToV8 already exists')
migration_path.write_text(migrations.replace(anchor, helper, 1))
