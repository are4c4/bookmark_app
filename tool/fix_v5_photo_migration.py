from pathlib import Path

path = Path('lib/data/app_database.dart')
text = path.read_text()
old = "          if (from < 7) await m.addColumn(photos, photos.tags);\n"
new = """          if (from < 7) {
            final photoColumns = await customSelect('PRAGMA table_info(photos)').get();
            final photoColumnNames =
                photoColumns.map((row) => row.read<String>('name')).toSet();
            if (!photoColumnNames.contains('tags')) {
              await m.addColumn(photos, photos.tags);
            }
          }
"""
if text.count(old) != 1:
    raise SystemExit(f'expected exactly one v7 photo migration line, found {text.count(old)}')
path.write_text(text.replace(old, new, 1))
