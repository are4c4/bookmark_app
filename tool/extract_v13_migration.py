from pathlib import Path

path = Path('lib/data/app_database.dart')
text = path.read_text()
old = """          if (from < 13) {
            final existing = await customSelect(
              \"SELECT name FROM sqlite_master WHERE type = 'table'\",
            ).get();
            final tableNames = existing.map((row) => row.read<String>('name')).toSet();

            if (!tableNames.contains('tag_groups')) {
              await m.createTable(tagGroups);
            }

            final tagColumns = await customSelect('PRAGMA table_info(tags)').get();
            final tagColumnNames = tagColumns.map((row) => row.read<String>('name')).toSet();
            if (!tagColumnNames.contains('group_id')) {
              await m.addColumn(tags, tags.groupId);
            }

            if (!tableNames.contains('bookmark_attachments')) {
              await m.createTable(bookmarkAttachments);
            }
            await customStatement(
              'CREATE INDEX IF NOT EXISTS bookmark_attachments_bookmark_id_idx '
              'ON bookmark_attachments(bookmark_id)',
            );

            if (!tableNames.contains('pdf_annotations')) {
              await m.createTable(pdfAnnotations);
            }
            await customStatement(
              'CREATE INDEX IF NOT EXISTS pdf_annotations_attachment_idx '
              'ON pdf_annotations(attachment_id, page_number)',
            );
          }
"""
new = """          if (from < 13) {
            await migrateToV13(m);
          }
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'Expected exactly one v13 migration block, found {count}')
path.write_text(text.replace(old, new, 1))
