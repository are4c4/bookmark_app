import 'dart:io';

import 'package:drift/native.dart';

/// Durable synthetic checkpoints used by historical migration regression tests.
///
/// Keep these schemas frozen once accepted. When a later destructive migration
/// needs a new supported checkpoint, add a new enum value/setup method instead
/// of rewriting an existing historical shape to match today's schema.
enum HistoricalDatabaseCheckpoint { legacyV8, objectEraV16 }

NativeDatabase historicalDatabaseExecutor(
  File file,
  HistoricalDatabaseCheckpoint checkpoint,
) {
  return NativeDatabase(
    file,
    setup: (sqlite) {
      final version = sqlite
          .select('PRAGMA user_version')
          .single['user_version'];
      if (version != 0) return;
      switch (checkpoint) {
        case HistoricalDatabaseCheckpoint.legacyV8:
          _createLegacyV8(sqlite);
        case HistoricalDatabaseCheckpoint.objectEraV16:
          _createObjectEraV16(sqlite);
      }
    },
  );
}

void _createLegacyV8(dynamic sqlite) {
  sqlite.execute('''
    CREATE TABLE bookmarks (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      url TEXT NOT NULL,
      title TEXT NOT NULL,
      thumbnail TEXT NULL,
      description TEXT NULL,
      tags TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      favorite INTEGER NOT NULL DEFAULT 0
    )
  ''');
  sqlite.execute(
    "INSERT INTO bookmarks(id, url, title, thumbnail, description, tags, created_at, favorite) "
    "VALUES (7, 'https://fixture.invalid/article', 'Synthetic legacy bookmark', "
    "'managed/thumbnails/synthetic.jpg', 'fixture description', 'alpha,beta', 1704067200, 1)",
  );

  sqlite.execute('''
    CREATE TABLE tags (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      parent_tag_id INTEGER NULL,
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
    )
  ''');

  sqlite.execute('''
    CREATE TABLE people (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      note TEXT NULL,
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
    )
  ''');
  sqlite.execute(
    "INSERT INTO people(id, name, note, created_at) "
    "VALUES (3, 'Synthetic Person', 'fixture note', 1704067201)",
  );

  sqlite.execute('''
    CREATE TABLE bookmark_people (
      bookmark_id INTEGER NOT NULL,
      person_id INTEGER NOT NULL,
      role TEXT NOT NULL DEFAULT '出演',
      PRIMARY KEY (bookmark_id, person_id)
    )
  ''');
  sqlite.execute(
    "INSERT INTO bookmark_people(bookmark_id, person_id, role) VALUES (7, 3, '出演')",
  );

  sqlite.execute('''
    CREATE TABLE photos (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      path TEXT NOT NULL UNIQUE,
      title TEXT NULL,
      note TEXT NULL,
      tags TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
    )
  ''');
  sqlite.execute(
    "INSERT INTO photos(id, path, title, note, tags, created_at) "
    "VALUES (4, 'managed/photos/synthetic-cover.jpg', 'Synthetic cover', "
    "'fixture media note', 'media', 1704067202)",
  );
  sqlite.execute('''
    CREATE TABLE bookmark_photos (
      bookmark_id INTEGER NOT NULL,
      photo_id INTEGER NOT NULL,
      is_cover INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (bookmark_id, photo_id)
    )
  ''');
  sqlite.execute(
    'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (7, 4, 1)',
  );

  sqlite.execute('''
    CREATE TABLE saved_views (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      layout_type TEXT NOT NULL DEFAULT 'gallery',
      search_query TEXT NOT NULL DEFAULT '',
      favorites_only INTEGER NOT NULL DEFAULT 0,
      tag_id INTEGER NULL,
      tag_match_mode TEXT NOT NULL DEFAULT 'or',
      sort_field TEXT NOT NULL DEFAULT 'createdAt',
      sort_direction TEXT NOT NULL DEFAULT 'desc',
      visible_properties TEXT NOT NULL DEFAULT 'image,url,tags,favorite',
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
    )
  ''');
  sqlite.execute(
    "INSERT INTO saved_views(id, name, layout_type, search_query, favorites_only, "
    "sort_field, sort_direction, visible_properties, created_at) "
    "VALUES (5, 'Synthetic legacy view', 'table', 'fixture needle', 1, "
    "'title', 'asc', 'image,url,tags', 1704067203)",
  );

  sqlite.execute('PRAGMA user_version = 8');
}

void _createObjectEraV16(dynamic sqlite) {
  // schemaVersion 16 was also the first long-lived Object-era checkpoint where
  // several Object contracts were additive/lazy tables. Preserve that real
  // historical shape instead of regenerating it from current Drift metadata.
  sqlite.execute('''
    CREATE TABLE workspaces (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL,
      icon TEXT NOT NULL DEFAULT '📁',
      color_value INTEGER NOT NULL DEFAULT 4288585374,
      sort_order INTEGER NOT NULL DEFAULT 0
    )
  ''');
  sqlite.execute(
    "INSERT INTO workspaces(id, name, created_at) VALUES "
    "(1, 'Synthetic Workspace', '2026-01-01T00:00:00.000Z')",
  );

  sqlite.execute('''
    CREATE TABLE generic_databases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      icon TEXT NOT NULL DEFAULT '🗃️',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  sqlite.execute(
    "INSERT INTO generic_databases(id, workspace_id, name, icon, sort_order, created_at) VALUES "
    "(20, 1, 'Person', '👤', 0, '2026-01-01T00:00:01.000Z'), "
    "(21, 1, 'Project', '📌', 1, '2026-01-01T00:00:02.000Z')",
  );

  sqlite.execute('''
    CREATE TABLE generic_properties (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      database_id INTEGER NOT NULL REFERENCES generic_databases(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      config_json TEXT NOT NULL DEFAULT '{}',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  sqlite.execute(
    "INSERT INTO generic_properties(id, database_id, name, type, config_json, sort_order, created_at) "
    "VALUES (30, 21, 'Members', 'relation', "
    "'{\"targetObjectTypeId\":20,\"multiple\":true}', 0, '2026-01-01T00:00:03.000Z')",
  );

  sqlite.execute('''
    CREATE TABLE generic_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      database_id INTEGER NOT NULL REFERENCES generic_databases(id) ON DELETE CASCADE,
      title TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  sqlite.execute(
    "INSERT INTO generic_records(id, database_id, title, created_at, updated_at) VALUES "
    "(100, 21, 'Synthetic Project', '2026-01-02T03:04:05.000Z', '2026-01-03T04:05:06.000Z'), "
    "(101, 20, 'Synthetic Alice', '2026-01-02T03:04:06.000Z', '2026-01-02T03:04:06.000Z'), "
    "(102, 20, 'Synthetic Bob', '2026-01-02T03:04:07.000Z', '2026-01-02T03:04:07.000Z')",
  );

  sqlite.execute('''
    CREATE TABLE generic_values (
      record_id INTEGER NOT NULL REFERENCES generic_records(id) ON DELETE CASCADE,
      property_id INTEGER NOT NULL REFERENCES generic_properties(id) ON DELETE CASCADE,
      value_json TEXT NOT NULL DEFAULT 'null',
      PRIMARY KEY(record_id, property_id)
    )
  ''');
  sqlite.execute(
    "INSERT INTO generic_values(record_id, property_id, value_json) VALUES (100, 30, '[101,102]')",
  );

  sqlite.execute('''
    CREATE TABLE object_bodies (
      object_id INTEGER PRIMARY KEY REFERENCES generic_records(id) ON DELETE CASCADE,
      document_json TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  sqlite.execute(
    "INSERT INTO object_bodies(object_id, document_json, updated_at) VALUES "
    "(100, '{\"version\":1,\"blocks\":[{\"id\":\"p-1\",\"type\":\"paragraph\",\"text\":\"First fixture block\"},{\"id\":\"p-2\",\"type\":\"paragraph\",\"text\":\"Second fixture block\"}]}', "
    "'2026-01-03T04:05:06.000Z')",
  );

  sqlite.execute('''
    CREATE TABLE object_relation_edges (
      source_object_id INTEGER NOT NULL REFERENCES generic_records(id) ON DELETE CASCADE,
      property_id INTEGER NOT NULL REFERENCES generic_properties(id) ON DELETE CASCADE,
      target_object_id INTEGER NOT NULL REFERENCES generic_records(id) ON DELETE CASCADE,
      position INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(source_object_id, property_id, target_object_id)
    )
  ''');
  sqlite.execute(
    'INSERT INTO object_relation_edges(source_object_id, property_id, target_object_id, position) '
    'VALUES (100, 30, 101, 0), (100, 30, 102, 1)',
  );

  sqlite.execute('''
    CREATE TABLE database_views (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
      database_key TEXT NOT NULL,
      name TEXT NOT NULL,
      layout_type TEXT NOT NULL DEFAULT 'gallery',
      filters_json TEXT NOT NULL DEFAULT '{}',
      sorts_json TEXT NOT NULL DEFAULT '[]',
      visible_properties TEXT NOT NULL DEFAULT '',
      property_order TEXT NOT NULL DEFAULT '',
      settings_json TEXT NOT NULL DEFAULT '{}',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  sqlite.execute(
    "INSERT INTO database_views(id, workspace_id, database_key, name, layout_type, filters_json, "
    "sorts_json, visible_properties, property_order, settings_json, sort_order, created_at) VALUES "
    "(40, 1, 'custom:21', 'Synthetic Project Table', 'table', "
    "'{\"operator\":\"and\",\"children\":[]}', '[{\"property\":\"title\",\"direction\":\"asc\"}]', "
    "'title,Members', 'title,30', '{\"density\":\"compact\"}', 0, '2026-01-04T00:00:00.000Z')",
  );

  sqlite.execute('PRAGMA user_version = 16');
}
