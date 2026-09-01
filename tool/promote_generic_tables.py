from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'anchor not found: {label}')
    return text.replace(old, new, 1)

# Formal Drift schema definitions.
p = Path('lib/data/app_database_schema.dart')
s = p.read_text()
anchor = """class BookmarkPeople extends Table {
  IntColumn get bookmarkId => integer().references(Bookmarks, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(People, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().withDefault(const Constant('出演者'))();
  @override
  Set<Column<Object>> get primaryKey => {bookmarkId, personId, role};
}

"""
insert = anchor + """@DataClassName('PersonGroupRecord')
class PersonGroups extends Table {
  @override
  String get tableName => 'person_groups';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PersonGroupMembers extends Table {
  @override
  String get tableName => 'person_group_members';

  IntColumn get groupId => integer().references(PersonGroups, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(People, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {groupId, personId};
}

"""
s = replace_once(s, anchor, insert, 'person group schema')

anchor = """class WorkspaceSettings extends Table {
  @override
  String get tableName => 'workspace_settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

"""
insert = anchor + """@DataClassName('DatabaseViewRecord')
class DatabaseViews extends Table {
  @override
  String get tableName => 'database_views';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId => integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get databaseKey => text()();
  TextColumn get name => text()();
  TextColumn get layoutType => text().withDefault(const Constant('gallery'))();
  TextColumn get filtersJson => text().withDefault(const Constant('{}'))();
  TextColumn get sortsJson => text().withDefault(const Constant('[]'))();
  TextColumn get visibleProperties => text().withDefault(const Constant(''))();
  TextColumn get propertyOrder => text().withDefault(const Constant(''))();
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

"""
s = replace_once(s, anchor, insert, 'database view schema')
p.write_text(s)

# Register tables and migration.
p = Path('lib/data/app_database.dart')
s = p.read_text()
s = replace_once(
    s,
    """    People,
    BookmarkPeople,
    Photos,
""",
    """    People,
    BookmarkPeople,
    PersonGroups,
    PersonGroupMembers,
    Photos,
""",
    'register person groups',
)
s = replace_once(
    s,
    """    WorkspaceSettings,
    BookmarkAttachments,
""",
    """    WorkspaceSettings,
    DatabaseViews,
    BookmarkAttachments,
""",
    'register database views',
)
s = replace_once(s, '  int get schemaVersion => 14;', '  int get schemaVersion => 15;', 'schema version')
s = replace_once(
    s,
    """          if (from < 14) {
            await m.addColumn(
              savedViews,
              savedViews.includeDescendants,
            );
            await m.addColumn(savedViews, savedViews.personFilterId);
            await m.addColumn(savedViews, savedViews.photoFilterId);
          }
""",
    """          if (from < 14) {
            await m.addColumn(
              savedViews,
              savedViews.includeDescendants,
            );
            await m.addColumn(savedViews, savedViews.personFilterId);
            await m.addColumn(savedViews, savedViews.photoFilterId);
          }
          if (from < 15) {
            final existing = await customSelect(
              \"SELECT name FROM sqlite_master WHERE type = 'table'\",
            ).get();
            final tableNames = existing.map((row) => row.read<String>('name')).toSet();
            if (!tableNames.contains('person_groups')) {
              await m.createTable(personGroups);
            }
            if (!tableNames.contains('person_group_members')) {
              await m.createTable(personGroupMembers);
            }
            if (!tableNames.contains('database_views')) {
              await m.createTable(databaseViews);
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
""",
    'v15 migration',
)
p.write_text(s)

print('generic tables promoted to Drift schema v15')
