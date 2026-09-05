from pathlib import Path

app_path = Path('lib/data/app_database.dart')
app = app_path.read_text()
old = """          if (from < 6) {
            await m.createTable(photos);
            await m.createTable(bookmarkPhotos);
          }
"""
new = "          if (from < 6) await migrateToV6(m);\n"
if app.count(old) != 1:
    raise SystemExit(f'expected exactly one inline v6 migration, found {app.count(old)}')
app_path.write_text(app.replace(old, new, 1))

migration_path = Path('lib/data/app_database_migrations.dart')
migrations = migration_path.read_text()
anchor = "extension AppDatabaseMigrationSteps on AppDatabase {\n"
helper = """extension AppDatabaseMigrationSteps on AppDatabase {
  Future<void> migrateToV6(Migrator migrator) async {
    await migrator.createTable(photos);
    await migrator.createTable(bookmarkPhotos);
  }

"""
if migrations.count(anchor) != 1:
    raise SystemExit(f'expected exactly one migration extension anchor, found {migrations.count(anchor)}')
if 'Future<void> migrateToV6(' in migrations:
    raise SystemExit('migrateToV6 already exists')
migration_path.write_text(migrations.replace(anchor, helper, 1))
