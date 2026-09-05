from pathlib import Path

path = Path('lib/data/app_database.dart')
text = path.read_text()
old = """          if (from < 14) {
            await m.addColumn(
              savedViews,
              savedViews.includeDescendants,
            );
            await m.addColumn(savedViews, savedViews.personFilterId);
            await m.addColumn(savedViews, savedViews.photoFilterId);
          }
"""
new = """          if (from < 14) {
            await migrateToV14(m);
          }
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'Expected exactly one v14 migration block, found {count}')
path.write_text(text.replace(old, new, 1))
