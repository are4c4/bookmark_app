from pathlib import Path

app_path = Path('lib/data/app_database.dart')
app = app_path.read_text()
old = """          if (from < 5) {
            await m.createTable(people);
            await m.createTable(bookmarkPeople);
          }
"""
new = "          if (from < 5) await migrateToV5(m);\n"
if app.count(old) != 1:
    raise SystemExit(f'expected exactly one inline v5 migration, found {app.count(old)}')
app_path.write_text(app.replace(old, new, 1))

migration_path = Path('lib/data/app_database_migrations.dart')
migrations = migration_path.read_text()
anchor = "extension AppDatabaseMigrationSteps on AppDatabase {\n"
helper = """extension AppDatabaseMigrationSteps on AppDatabase {
  Future<void> migrateToV5(Migrator migrator) async {
    await migrator.createTable(people);
    await migrator.createTable(bookmarkPeople);
  }

"""
if migrations.count(anchor) != 1:
    raise SystemExit(f'expected exactly one migration extension anchor, found {migrations.count(anchor)}')
if 'Future<void> migrateToV5(' in migrations:
    raise SystemExit('migrateToV5 already exists')
migration_path.write_text(migrations.replace(anchor, helper, 1))
