from pathlib import Path

app_path = Path('lib/data/app_database.dart')
app = app_path.read_text()
old = """          if (from < 7) {
            final photoColumns = await customSelect('PRAGMA table_info(photos)').get();
            final photoColumnNames =
                photoColumns.map((row) => row.read<String>('name')).toSet();
            if (!photoColumnNames.contains('tags')) {
              await m.addColumn(photos, photos.tags);
            }
          }
"""
new = "          if (from < 7) await migrateToV7(m);\n"
if app.count(old) != 1:
    raise SystemExit(f'expected exactly one inline v7 migration, found {app.count(old)}')
app_path.write_text(app.replace(old, new, 1))

migration_path = Path('lib/data/app_database_migrations.dart')
migrations = migration_path.read_text()
anchor = "extension AppDatabaseMigrationSteps on AppDatabase {\n"
helper = """extension AppDatabaseMigrationSteps on AppDatabase {
  Future<void> migrateToV7(Migrator migrator) async {
    final photoColumns = await customSelect('PRAGMA table_info(photos)').get();
    final photoColumnNames =
        photoColumns.map((row) => row.read<String>('name')).toSet();
    if (!photoColumnNames.contains('tags')) {
      await migrator.addColumn(photos, photos.tags);
    }
  }

"""
if migrations.count(anchor) != 1:
    raise SystemExit(f'expected exactly one migration extension anchor, found {migrations.count(anchor)}')
if 'Future<void> migrateToV7(' in migrations:
    raise SystemExit('migrateToV7 already exists')
migration_path.write_text(migrations.replace(anchor, helper, 1))
