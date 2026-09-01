from pathlib import Path
import re


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing patch target: {label}')
    return text.replace(old, new, 1)


def sub_once(text, pattern, repl, label, flags=0):
    new, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'expected one regex match for {label}, got {count}')
    return new

# ---- app shell: custom databases + clean old unused helper ----
path = 'lib/views/app_shell.dart'
text = read(path)
text = replace_once(
    text,
    "import '../data/bookmark_repository.dart';\n",
    "import '../data/bookmark_repository.dart';\nimport '../data/generic_database_store.dart';\n",
    'app shell generic store import',
)
text = replace_once(
    text,
    "import 'global_search_page.dart';\n",
    "import 'global_search_page.dart';\nimport 'generic_database_page.dart';\n",
    'app shell generic page import',
)
text = replace_once(
    text,
    "  List<WorkspaceInfo> _workspaces = const [];\n  final Map<int, Widget> _pageCache = {};\n",
    "  List<WorkspaceInfo> _workspaces = const [];\n  List<GenericDatabaseDefinitionRecord> _genericDatabases = const [];\n  int? _selectedGenericDatabaseId;\n  final Map<int, Widget> _pageCache = {};\n",
    'app shell generic fields',
)
text = replace_once(
    text,
    "      _pageCache.clear();\n      _reloadWorkspaces();\n",
    "      _pageCache.clear();\n      _selectedGenericDatabaseId = null;\n      _reloadWorkspaces();\n",
    'app shell repository change',
)
text = replace_once(
    text,
    "      _loadingWorkspaces = false;\n    });\n  }\n\n  WorkspaceInfo? get _activeWorkspace",
    "      _loadingWorkspaces = false;\n    });\n    await _reloadGenericDatabases();\n  }\n\n  Future<void> _reloadGenericDatabases() async {\n    final store = GenericDatabaseStore(widget.repository.workspaceStore.database);\n    final databases = await store.listDatabases(widget.repository.workspaceId);\n    if (!mounted) return;\n    setState(() {\n      _genericDatabases = databases;\n      if (_selectedGenericDatabaseId != null &&\n          !databases.any((item) => item.id == _selectedGenericDatabaseId)) {\n        _selectedGenericDatabaseId = null;\n      }\n      _pageCache.remove(11);\n    });\n  }\n\n  Future<void> _createGenericDatabase() async {\n    final name = await _askName('データベースを追加', hint: '例: 書籍');\n    if (name?.isNotEmpty != true) return;\n    final store = GenericDatabaseStore(widget.repository.workspaceStore.database);\n    final id = await store.createDatabase(\n      workspaceId: widget.repository.workspaceId,\n      name: name!,\n    );\n    await _reloadGenericDatabases();\n    if (!mounted) return;\n    setState(() {\n      _selectedGenericDatabaseId = id;\n      _index = 11;\n      _pageCache.remove(11);\n    });\n  }\n\n  WorkspaceInfo? get _activeWorkspace",
    'app shell reload generic dbs',
)
text = sub_once(
    text,
    r"\n  Widget _subNavTile\(int index, IconData icon, String label\) \{.*?\n  \}\n\n  Widget _expandedSidebar",
    "\n\n  Widget _genericDatabaseTile(GenericDatabaseDefinitionRecord database) {\n    final scheme = Theme.of(context).colorScheme;\n    final selected = _index == 11 && _selectedGenericDatabaseId == database.id;\n    return Padding(\n      padding: const EdgeInsets.symmetric(horizontal: UiTokens.space6, vertical: 1),\n      child: Material(\n        color: selected ? scheme.surfaceContainerHigh : Colors.transparent,\n        borderRadius: BorderRadius.circular(UiTokens.radiusSm),\n        child: InkWell(\n          borderRadius: BorderRadius.circular(UiTokens.radiusSm),\n          onTap: () => setState(() {\n            _selectedGenericDatabaseId = database.id;\n            _index = 11;\n            _pageCache.remove(11);\n          }),\n          child: SizedBox(\n            height: UiTokens.sidebarRowHeight,\n            child: Padding(\n              padding: const EdgeInsets.symmetric(horizontal: 9),\n              child: Row(children: [\n                Text(database.icon, style: const TextStyle(fontSize: 14)),\n                const SizedBox(width: 9),\n                Expanded(\n                  child: Text(\n                    database.name,\n                    maxLines: 1,\n                    overflow: TextOverflow.ellipsis,\n                    style: TextStyle(\n                      fontSize: UiTokens.textMd,\n                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,\n                    ),\n                  ),\n                ),\n              ]),\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n\n  Widget _expandedSidebar",
    'remove sub nav and add generic tile',
    flags=re.S,
)
text = replace_once(
    text,
    "              _navTile(8, Icons.collections_bookmark_outlined, 'コレクション'),\n              const SizedBox(height: UiTokens.space6),\n",
    "              _navTile(8, Icons.collections_bookmark_outlined, 'コレクション'),\n              ..._genericDatabases.map(_genericDatabaseTile),\n              Padding(\n                padding: const EdgeInsets.symmetric(horizontal: UiTokens.space6, vertical: 1),\n                child: InkWell(\n                  borderRadius: BorderRadius.circular(UiTokens.radiusSm),\n                  onTap: _createGenericDatabase,\n                  child: const SizedBox(\n                    height: UiTokens.sidebarRowHeight,\n                    child: Padding(\n                      padding: EdgeInsets.symmetric(horizontal: 9),\n                      child: Row(children: [\n                        Icon(Icons.add, size: UiTokens.iconNormal),\n                        SizedBox(width: 9),\n                        Text('データベースを追加', style: TextStyle(fontSize: UiTokens.textMd)),\n                      ]),\n                    ),\n                  ),\n                ),\n              ),\n              const SizedBox(height: UiTokens.space6),\n",
    'app shell custom nav entries',
)
text = replace_once(
    text,
    "        9 => ProfileManagementPage(\n",
    "        9 => ProfileManagementPage(\n",
    'app shell anchor profile',
)
text = replace_once(
    text,
    "        _ => SettingsPage(\n            themeMode: widget.themeMode,\n            onThemeModeChanged: widget.onThemeModeChanged,\n            repository: widget.repository,\n          ),\n      };",
    "        10 => SettingsPage(\n            themeMode: widget.themeMode,\n            onThemeModeChanged: widget.onThemeModeChanged,\n            repository: widget.repository,\n          ),\n        11 => _selectedGenericDatabaseId == null\n            ? Center(\n                child: FilledButton.icon(\n                  onPressed: _createGenericDatabase,\n                  icon: const Icon(Icons.add),\n                  label: const Text('データベースを作成'),\n                ),\n              )\n            : GenericDatabasePage(\n                key: ValueKey(_selectedGenericDatabaseId),\n                repository: widget.repository,\n                databaseId: _selectedGenericDatabaseId!,\n                onDatabaseChanged: _reloadGenericDatabases,\n              ),\n        _ => const SizedBox.shrink(),\n      };",
    'app shell generic page route',
)
text = replace_once(
    text,
    "  List<Widget> _lazyPages(WorkspaceInfo? workspace) {\n    _pageCache.putIfAbsent(_index, () => _buildPage(_index, workspace));\n    return List<Widget>.generate(\n      11,\n",
    "  List<Widget> _lazyPages(WorkspaceInfo? workspace) {\n    if (_index == 11) {\n      _pageCache[11] = _buildPage(11, workspace);\n    } else {\n      _pageCache.putIfAbsent(_index, () => _buildPage(_index, workspace));\n    }\n    return List<Widget>.generate(\n      12,\n",
    'app shell page count',
)
write(path, text)

# ---- property order: preserve detail-only keys ----
path = 'lib/views/bookmark_property_order.dart'
text = read(path)
text = replace_once(
    text,
    "import 'bookmark_query_engine.dart';\n\n",
    "import 'bookmark_query_engine.dart';\n\nconst bookmarkDetailOnlyPropertyKeys = <String>{\n  'genre',\n  'collections',\n};\n\n",
    'detail only keys declaration',
)
text = replace_once(
    text,
    "    if (key.startsWith('role:') || bookmarkPropertyFromKey(key) != null) {\n      result.add(key);\n    }\n",
    "    if (key.startsWith('role:') ||\n        bookmarkPropertyFromKey(key) != null ||\n        bookmarkDetailOnlyPropertyKeys.contains(key)) {\n      result.add(key);\n    }\n",
    'normalize detail keys',
)
text = replace_once(
    text,
    "      ...BookmarkStage1Property.values.map(bookmarkPropertyKey),\n      ...defaultPersonRoles.map((role) => 'role:$role'),\n",
    "      ...BookmarkStage1Property.values.map(bookmarkPropertyKey),\n      'genre',\n      ...defaultPersonRoles.map((role) => 'role:$role'),\n      'collections',\n",
    'default detail key order',
)
write(path, text)

# ---- bookmark detail panel: swap fixed rows for reorderable section ----
path = 'lib/widgets/bookmark_detail_panel.dart'
text = read(path)
text = replace_once(
    text,
    "import 'bookmark_relation_section.dart';\nimport 'detail_property_row.dart';\nimport 'person_role_properties.dart';\n",
    "import 'bookmark_relation_section.dart';\nimport 'bookmark_reorderable_properties.dart';\n",
    'detail imports',
)
text = replace_once(
    text,
    "import 'relation_database_picker.dart';\n",
    "",
    'remove relation picker import',
)
text = replace_once(
    text,
    "    this.onFilterByPhoto,\n  });",
    "    this.onFilterByPhoto,\n    this.propertyOrder = const [],\n    this.onPropertyOrderChanged,\n  });",
    'detail constructor args',
)
text = replace_once(
    text,
    "  final ValueChanged<PhotoRecord>? onFilterByPhoto;\n",
    "  final ValueChanged<PhotoRecord>? onFilterByPhoto;\n  final List<String> propertyOrder;\n  final ValueChanged<List<String>>? onPropertyOrderChanged;\n",
    'detail fields',
)
text = sub_once(
    text,
    r"\n  String _formatDateTime\(DateTime\? value\) \{.*?\n  \}\n\n  Future<void> _openUrl",
    "\n\n  Future<void> _openUrl",
    'remove old datetime helper',
    flags=re.S,
)
text = sub_once(
    text,
    r"\n  Future<Tag\?> _createTagFromPicker.*?\n  Future<void> _addPhotosFromDatabase",
    "\n\n  Future<void> _addPhotosFromDatabase",
    'remove old tag collection helpers',
    flags=re.S,
)
text = sub_once(
    text,
    r"\n  Widget _propertyRow\(\{.*?\n  Widget _inlineTitle",
    "\n\n  Widget _inlineTitle",
    'remove old property row helpers',
    flags=re.S,
)
text = sub_once(
    text,
    r"\n                        _propertyRow\(\n                          icon: Icons\.flag_outlined,.*?\n                        const SizedBox\(height: 18\),\n                        Divider",
    "\n                        BookmarkReorderableProperties(\n                          repository: widget.repository,\n                          bookmark: bookmark,\n                          propertyOrder: widget.propertyOrder,\n                          onPropertyOrderChanged: (order) =>\n                              widget.onPropertyOrderChanged?.call(order),\n                          onFilterByTag: widget.onFilterByTag,\n                          onFilterByPerson: widget.onFilterByPerson,\n                        ),\n                        const SizedBox(height: 18),\n                        Divider",
    'replace fixed property rows',
    flags=re.S,
)
write(path, text)

# ---- bookmark page: sync detail reorder to active view and clear old warnings ----
path = 'lib/views/bookmark_unified_stage1_page.dart'
text = read(path)
text = replace_once(
    text,
    "  DatabaseViewConfig? _activeDatabaseView;\n",
    "  DatabaseViewConfig? _activeDatabaseView;\n\n  bool get _legacyBookmarkSidebarEnabled => false;\n",
    'legacy sidebar getter',
)
text = sub_once(
    text,
    r"\n  List<String> _orderedListDetails\(.*?\n  Widget _list\(",
    "\n\n  Widget _list(",
    'remove old list details',
    flags=re.S,
)
text = replace_once(
    text,
    "                  const showSidebar = false;\n",
    "                  final showSidebar = _legacyBookmarkSidebarEnabled;\n",
    'avoid dead sidebar branches',
)
text = replace_once(
    text,
    "                            bookmark: selected,\n                            onClose:",
    "                            bookmark: selected,\n                            propertyOrder: _propertyOrder,\n                            onPropertyOrderChanged: (order) {\n                              setState(() {\n                                _propertyOrder = normalizeBookmarkPropertyOrder(order);\n                                _markViewChanged();\n                              });\n                            },\n                            onClose:",
    'detail property order wiring',
)
write(path, text)

# ---- database view tabs: Flutter 3.47 reorder API ----
path = 'lib/widgets/database_view_tabs.dart'
text = read(path)
text = replace_once(
    text,
    "              onReorder: (oldIndex, newIndex) async {\n                if (newIndex > oldIndex) newIndex--;\n",
    "              onReorderItem: (oldIndex, newIndex) async {\n",
    'view tabs reorder API',
)
write(path, text)

# ---- generic page: Flutter 3.47 reorder API + rating int ----
path = 'lib/views/generic_database_page.dart'
text = read(path)
text = replace_once(
    text,
    "return '★' * value.toInt().clamp(0, 5);",
    "return '★' * value.toInt().clamp(0, 5).toInt();",
    'generic rating int',
)
text = replace_once(
    text,
    "                  onReorder: (oldIndex, newIndex) async {\n                    if (newIndex > oldIndex) newIndex--;\n",
    "                  onReorderItem: (oldIndex, newIndex) async {\n",
    'generic detail reorder API',
)
write(path, text)

# ---- database view duplication: allow custom database keys ----
path = 'lib/data/database_view_store.dart'
text = read(path)
text = sub_once(
    text,
    r"  Future<int> duplicateView\(DatabaseViewConfig view\) async \{.*?\n  \}\n\n  Future<void> deleteView",
    """  Future<int> duplicateView(DatabaseViewConfig view) async {
    await _ensureSchema();
    final views = await listViews(
      workspaceId: view.workspaceId,
      databaseKey: view.databaseKey,
    );
    final nextOrder = views.isEmpty
        ? 0
        : views.map((item) => item.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await database.customStatement(
      '''
      INSERT INTO database_views(
        workspace_id, database_key, name, layout_type, filters_json,
        sorts_json, visible_properties, property_order, settings_json,
        sort_order
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        view.workspaceId,
        view.databaseKey,
        '${view.name} のコピー',
        view.layoutType,
        jsonEncode(view.filters),
        jsonEncode(view.sorts),
        view.visibleProperties.join(','),
        view.propertyOrder.join(','),
        jsonEncode(view.settings),
        nextOrder,
      ],
    );
    final row = await database.customSelect(
      'SELECT id FROM database_views WHERE workspace_id = ? AND database_key = ? ORDER BY id DESC LIMIT 1',
      variables: [Variable<int>(view.workspaceId), Variable<String>(view.databaseKey)],
    ).getSingle();
    return row.read<int>('id');
  }

  Future<void> deleteView""",
    'custom view duplication',
    flags=re.S,
)
write(path, text)

# ---- Drift schema v16: generic database tables are first-class ----
path = 'lib/data/app_database_schema.dart'
text = read(path)
anchor = "@DataClassName('BookmarkAttachmentRecord')\nclass BookmarkAttachments extends Table {"
generic_tables = """@DataClassName('GenericDatabaseRow')
class GenericDatabases extends Table {
  @override
  String get tableName => 'generic_databases';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId => integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('🗃️'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('GenericPropertyRow')
class GenericProperties extends Table {
  @override
  String get tableName => 'generic_properties';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get databaseId => integer().references(GenericDatabases, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get configJson => text().withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('GenericRecordRow')
class GenericRecords extends Table {
  @override
  String get tableName => 'generic_records';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get databaseId => integer().references(GenericDatabases, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class GenericValues extends Table {
  @override
  String get tableName => 'generic_values';

  IntColumn get recordId => integer().references(GenericRecords, #id, onDelete: KeyAction.cascade)();
  IntColumn get propertyId => integer().references(GenericProperties, #id, onDelete: KeyAction.cascade)();
  TextColumn get valueJson => text().withDefault(const Constant('null'))();

  @override
  Set<Column<Object>> get primaryKey => {recordId, propertyId};
}

"""
text = replace_once(text, anchor, generic_tables + anchor, 'generic drift tables')
write(path, text)

path = 'lib/data/app_database.dart'
text = read(path)
text = replace_once(
    text,
    "    DatabaseViews,\n    BookmarkAttachments,\n",
    "    DatabaseViews,\n    GenericDatabases,\n    GenericProperties,\n    GenericRecords,\n    GenericValues,\n    BookmarkAttachments,\n",
    'generic tables in DriftDatabase',
)
text = replace_once(text, "  int get schemaVersion => 15;", "  int get schemaVersion => 16;", 'schema v16')
text = replace_once(
    text,
    "          if (from < 15) {",
    "          if (from < 15) {",
    'v15 anchor',
)
needle = """          }
        },
        beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
"""
insert = """          }
          if (from < 16) {
            final existing = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            ).get();
            final tableNames = existing.map((row) => row.read<String>('name')).toSet();
            if (!tableNames.contains('generic_databases')) {
              await m.createTable(genericDatabases);
            }
            if (!tableNames.contains('generic_properties')) {
              await m.createTable(genericProperties);
            }
            if (!tableNames.contains('generic_records')) {
              await m.createTable(genericRecords);
            }
            if (!tableNames.contains('generic_values')) {
              await m.createTable(genericValues);
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
        },
        beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
"""
text = replace_once(text, needle, insert, 'generic v16 migration')
write(path, text)
