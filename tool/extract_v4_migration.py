from pathlib import Path

app_path = Path('lib/data/app_database.dart')
app_text = app_path.read_text()
old_block = """          if (from < 4) {
            await m.addColumn(savedViews, savedViews.tagMatchMode);
            await m.addColumn(savedViews, savedViews.sortField);
            await m.addColumn(savedViews, savedViews.sortDirection);
            await m.createTable(savedViewTags);
            await customStatement('''
              INSERT OR IGNORE INTO saved_view_tags (saved_view_id, tag_id)
              SELECT id, tag_id
              FROM saved_views
              WHERE tag_id IS NOT NULL
            ''');
          }
"""
new_block = """          if (from < 4) await migrateToV4(m);
"""
count = app_text.count(old_block)
if count != 1:
    raise SystemExit(f'expected exactly one v4 migration block, found {count}')
app_path.write_text(app_text.replace(old_block, new_block, 1))

migrations_path = Path('lib/data/app_database_migrations.dart')
migrations_text = migrations_path.read_text()
anchor = "extension AppDatabaseMigrationSteps on AppDatabase {\n"
if migrations_text.count(anchor) != 1:
    raise SystemExit('migration extension anchor mismatch')
helper = """  Future<void> migrateToV4(Migrator migrator) async {
    await migrator.addColumn(savedViews, savedViews.tagMatchMode);
    await migrator.addColumn(savedViews, savedViews.sortField);
    await migrator.addColumn(savedViews, savedViews.sortDirection);
    await migrator.createTable(savedViewTags);
    await customStatement('''
      INSERT OR IGNORE INTO saved_view_tags (saved_view_id, tag_id)
      SELECT id, tag_id
      FROM saved_views
      WHERE tag_id IS NOT NULL
    ''');
  }

"""
migrations_path.write_text(migrations_text.replace(anchor, anchor + helper, 1))
