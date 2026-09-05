part of 'app_database.dart';

extension AppDatabaseMigrationSteps on AppDatabase {
  Future<void> migrateToV7(Migrator migrator) async {
    final photoColumns = await customSelect('PRAGMA table_info(photos)').get();
    final photoColumnNames =
        photoColumns.map((row) => row.read<String>('name')).toSet();
    if (!photoColumnNames.contains('tags')) {
      await migrator.addColumn(photos, photos.tags);
    }
  }

  Future<void> migrateToV8(Migrator migrator) async {
    await migrator.addColumn(savedViews, savedViews.visibleProperties);
  }

  Future<void> migrateToV9(Migrator migrator) async {
    await migrator.addColumn(bookmarks, bookmarks.status);
    await migrator.addColumn(bookmarks, bookmarks.rating);
    await migrator.addColumn(bookmarks, bookmarks.lastOpenedAt);
    await migrator.addColumn(bookmarks, bookmarks.openCount);

    final peopleColumns = await customSelect('PRAGMA table_info(people)').get();
    final peopleColumnNames =
        peopleColumns.map((row) => row.read<String>('name')).toSet();
    if (!peopleColumnNames.contains('profile_photo_id')) {
      await migrator.addColumn(people, people.profilePhotoId);
    }

    await migrator.addColumn(savedViews, savedViews.statusFilter);
    await migrator.addColumn(savedViews, savedViews.minRating);
    await migrator.createTable(collections);
    await migrator.createTable(bookmarkCollections);
    await migrator.createTable(bookmarkRelations);
  }

  Future<void> migrateToV10(Migrator migrator) async {
    await customStatement('ALTER TABLE bookmark_people RENAME TO bookmark_people_old');
    await customStatement(
      "CREATE TABLE bookmark_people ("
      "bookmark_id INTEGER NOT NULL REFERENCES bookmarks(id) ON DELETE CASCADE, "
      "person_id INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE, "
      "role TEXT NOT NULL DEFAULT '出演者', "
      "PRIMARY KEY (bookmark_id, person_id, role))",
    );
    await customStatement(
      "INSERT OR IGNORE INTO bookmark_people (bookmark_id, person_id, role) "
      "SELECT bookmark_id, person_id, CASE WHEN role = '出演' OR role = 'performer' THEN '出演者' ELSE role END "
      "FROM bookmark_people_old",
    );
    await customStatement('DROP TABLE bookmark_people_old');
  }

  Future<void> migrateToV11(Migrator migrator) async {
    final info = await customSelect('PRAGMA table_info(bookmarks)').get();
    final names = info.map((row) => row.read<String>('name')).toSet();

    if (!names.contains('reading_status')) {
      await migrator.addColumn(bookmarks, bookmarks.readingStatus);
    }
    if (!names.contains('storage_state')) {
      await migrator.addColumn(bookmarks, bookmarks.storageState);
    }
    if (!names.contains('genre')) {
      await migrator.addColumn(bookmarks, bookmarks.genre);
    }
    if (!names.contains('deleted_at')) {
      await migrator.addColumn(bookmarks, bookmarks.deletedAt);
    }

    await customStatement('''
      UPDATE bookmarks
      SET reading_status = CASE
            WHEN status IN ('unread', 'later', 'in_progress', 'done') THEN status
            ELSE 'unread'
          END,
          storage_state = CASE
            WHEN status = 'archived' THEN 'archived'
            ELSE storage_state
          END
    ''');

    if (names.contains('inbox_state')) {
      await customStatement('''
        UPDATE bookmarks
        SET storage_state = 'inbox'
        WHERE inbox_state = 1 AND storage_state != 'trash'
      ''');
    }

    if (names.contains('genre_state')) {
      await customStatement('''
        UPDATE bookmarks
        SET genre = genre_state
        WHERE genre_state IS NOT NULL AND genre_state != ''
      ''');
    }

    if (names.contains('deleted_at_state')) {
      final deletedRows = await customSelect('''
        SELECT id, deleted_at_state
        FROM bookmarks
        WHERE deleted_at_state IS NOT NULL
      ''').get();
      for (final row in deletedRows) {
        final raw = row.readNullable<String>('deleted_at_state');
        final parsed = raw == null ? null : DateTime.tryParse(raw);
        await (update(bookmarks)..where((b) => b.id.equals(row.read<int>('id')))).write(
          BookmarksCompanion(
            storageState: const Value('trash'),
            deletedAt: Value(parsed),
          ),
        );
      }
    }
  }

  Future<void> migrateToV12(Migrator migrator) async {
    final existing = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final tableNames = existing.map((row) => row.read<String>('name')).toSet();

    if (!tableNames.contains('workspaces')) {
      await migrator.createTable(workspaces);
    } else {
      final columns = await customSelect('PRAGMA table_info(workspaces)').get();
      final names = columns.map((row) => row.read<String>('name')).toSet();
      if (!names.contains('icon')) {
        await customStatement(
          "ALTER TABLE workspaces ADD COLUMN icon TEXT NOT NULL DEFAULT '📁'",
        );
      }
      if (!names.contains('color_value')) {
        await customStatement(
          'ALTER TABLE workspaces ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4288585374',
        );
      }
      if (!names.contains('sort_order')) {
        await customStatement(
          'ALTER TABLE workspaces ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (!tableNames.contains('bookmark_workspace')) {
      await migrator.createTable(bookmarkWorkspaces);
    }
    if (!tableNames.contains('saved_view_workspace')) {
      await migrator.createTable(savedViewWorkspaces);
    }
    if (!tableNames.contains('workspace_settings')) {
      await migrator.createTable(workspaceSettings);
    }
  }

  Future<void> migrateToV13(Migrator migrator) async {
    final existing = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final tableNames = existing.map((row) => row.read<String>('name')).toSet();

    if (!tableNames.contains('tag_groups')) {
      await migrator.createTable(tagGroups);
    }

    final tagColumns = await customSelect('PRAGMA table_info(tags)').get();
    final tagColumnNames = tagColumns.map((row) => row.read<String>('name')).toSet();
    if (!tagColumnNames.contains('group_id')) {
      await migrator.addColumn(tags, tags.groupId);
    }

    if (!tableNames.contains('bookmark_attachments')) {
      await migrator.createTable(bookmarkAttachments);
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS bookmark_attachments_bookmark_id_idx '
      'ON bookmark_attachments(bookmark_id)',
    );

    if (!tableNames.contains('pdf_annotations')) {
      await migrator.createTable(pdfAnnotations);
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS pdf_annotations_attachment_idx '
      'ON pdf_annotations(attachment_id, page_number)',
    );
  }

  Future<void> migrateToV14(Migrator migrator) async {
    await migrator.addColumn(
      savedViews,
      savedViews.includeDescendants,
    );
    await migrator.addColumn(savedViews, savedViews.personFilterId);
    await migrator.addColumn(savedViews, savedViews.photoFilterId);
  }

  Future<void> migrateToV15(Migrator migrator) async {
    final existing = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final tableNames = existing.map((row) => row.read<String>('name')).toSet();

    if (!tableNames.contains('person_groups')) {
      await migrator.createTable(personGroups);
    }
    if (!tableNames.contains('person_group_members')) {
      await migrator.createTable(personGroupMembers);
    }
    if (!tableNames.contains('database_views')) {
      await migrator.createTable(databaseViews);
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS person_group_members_person_idx '
      'ON person_group_members(person_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS database_views_scope_idx '
      'ON database_views(workspace_id, database_key, sort_order, id)',
    );
  }

  Future<void> migrateToV16(Migrator migrator) async {
    final existing = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final tableNames = existing.map((row) => row.read<String>('name')).toSet();

    if (!tableNames.contains('generic_databases')) {
      await migrator.createTable(genericDatabases);
    }
    if (!tableNames.contains('generic_properties')) {
      await migrator.createTable(genericProperties);
    }
    if (!tableNames.contains('generic_records')) {
      await migrator.createTable(genericRecords);
    }
    if (!tableNames.contains('generic_values')) {
      await migrator.createTable(genericValues);
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS generic_databases_workspace_idx '
      'ON generic_databases(workspace_id, sort_order, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS generic_properties_database_idx '
      'ON generic_properties(database_id, sort_order, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS generic_records_database_idx '
      'ON generic_records(database_id, updated_at DESC, id DESC)',
    );
  }
}
