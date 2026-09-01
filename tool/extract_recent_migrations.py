from pathlib import Path

path = Path('lib/data/app_database.dart')
text = path.read_text()
part_line = "part 'app_database_migrations.dart';\n"
marker = "part 'app_database_schema.dart';\n"
if part_line not in text:
    if marker not in text:
        raise SystemExit('part marker not found')
    text = text.replace(marker, marker + part_line, 1)

start = text.index('          if (from < 15) {')
end = text.index('        },\n        beforeOpen:', start)
replacement = '''          if (from < 15) {
            await migrateToV15(m);
          }
          if (from < 16) {
            await migrateToV16(m);
          }
'''
text = text[:start] + replacement + text[end:]
path.write_text(text)
