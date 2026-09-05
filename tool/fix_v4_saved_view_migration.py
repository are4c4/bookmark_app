from pathlib import Path

path = Path('lib/data/app_database.dart')
text = path.read_text()
old = """            final oldViews = await select(savedViews).get();
            for (final view in oldViews) {
              if (view.tagId != null) {
                await into(savedViewTags).insert(
                  SavedViewTagsCompanion.insert(savedViewId: view.id, tagId: view.tagId!),
                  mode: InsertMode.insertOrIgnore,
                );
              }
            }
"""
new = """            await customStatement('''
              INSERT OR IGNORE INTO saved_view_tags (saved_view_id, tag_id)
              SELECT id, tag_id
              FROM saved_views
              WHERE tag_id IS NOT NULL
            ''');
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected exactly one v4 saved-view migration loop, found {count}')
path.write_text(text.replace(old, new, 1))
