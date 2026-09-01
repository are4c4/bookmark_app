from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'anchor not found: {label}')
    return text.replace(old, new, 1)

# Collections use the same generic view model (currently list rendering only).
p = Path('lib/views/collection_management_page.dart')
s = p.read_text()
s = replace_once(
    s,
    "import 'package:drift/drift.dart' hide Column;\n",
    "import 'dart:async';\n\nimport 'package:drift/drift.dart' hide Column;\n",
    'collection async import',
)
s = replace_once(
    s,
    "import '../data/bookmark_repository.dart';\n",
    "import '../data/bookmark_repository.dart';\nimport '../data/database_view_store.dart';\nimport '../database/database_definition.dart';\n",
    'collection generic imports',
)
s = replace_once(
    s,
    "import '../widgets/database_page_toolbar.dart';\n",
    "import '../widgets/database_page_toolbar.dart';\nimport '../widgets/database_view_tabs.dart';\n",
    'collection tabs import',
)
s = replace_once(
    s,
    """  int? _selectedCollectionId;
  String _query = '';

  BookmarkRepository get repository => widget.repository;
""",
    """  int? _selectedCollectionId;
  String _query = '';
  late final DatabaseViewStore _databaseViewStore;
  DatabaseViewConfig? _activeDatabaseView;
  int? _activeDatabaseViewId;
  Timer? _viewSaveTimer;

  BookmarkRepository get repository => widget.repository;
""",
    'collection fields',
)
s = replace_once(
    s,
    """  AppDatabase get database => repository.workspaceStore.database;

  Future<void> _createInline(String name) async {
""",
    """  AppDatabase get database => repository.workspaceStore.database;

  @override
  void initState() {
    super.initState();
    _databaseViewStore = DatabaseViewStore(database);
  }

  @override
  void dispose() {
    _viewSaveTimer?.cancel();
    super.dispose();
  }

  void _applyDatabaseView(DatabaseViewConfig view) {
    setState(() {
      _activeDatabaseView = view;
      _activeDatabaseViewId = view.id;
      _query = (view.filters['query'] as String?) ?? '';
    });
  }

  void _markDatabaseViewChanged() {
    final active = _activeDatabaseView;
    if (active == null) return;
    _viewSaveTimer?.cancel();
    _viewSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _activeDatabaseViewId != active.id) return;
      final next = active.copyWith(
        layoutType: 'list',
        filters: {'query': _query},
      );
      await _databaseViewStore.updateView(next);
      if (mounted && _activeDatabaseViewId == active.id) _activeDatabaseView = next;
    });
  }

  Widget _databaseViewTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 10, 0),
        child: DatabaseViewTabs(
          store: _databaseViewStore,
          definition: BuiltInDatabases.collections,
          workspaceId: repository.workspaceId,
          activeViewId: _activeDatabaseViewId,
          onSelected: _applyDatabaseView,
        ),
      );

  Future<void> _createInline(String name) async {
""",
    'collection generic methods',
)
s = replace_once(
    s,
    """        children: [
          DatabasePageToolbar(
            title: 'コレクション',
            searchHint: 'コレクションを検索',
            onSearchChanged: (value) => setState(() => _query = value),
""",
    """        children: [
          _databaseViewTabs(),
          DatabasePageToolbar(
            title: 'コレクション',
            searchHint: 'コレクションを検索',
            searchValue: _query,
            onSearchChanged: (value) => setState(() {
              _query = value;
              _markDatabaseViewChanged();
            }),
""",
    'collection build tabs',
)
p.write_text(s)

# Keep search controls in sync when changing views.
for path, title in [
    ('lib/views/people_management_page.dart', '人物'),
    ('lib/views/photo_management_page.dart', '写真'),
]:
    p = Path(path)
    s = p.read_text()
    anchor = f"            title: '{title}',\n            searchHint: '{title}を検索',\n"
    if anchor in s and f"            searchValue: _query,\n" not in s[s.index(anchor):s.index(anchor)+200]:
        s = s.replace(anchor, anchor + "            searchValue: _query,\n", 1)
    p.write_text(s)

# Collections currently have one renderer, so only advertise the supported list layout.
p = Path('lib/database/database_definition.dart')
s = p.read_text()
s = replace_once(
    s,
    """    defaultLayout: 'list',
  );
""",
    """    defaultLayout: 'list',
    supportedLayouts: ['list'],
  );
""",
    'collection supported layout',
)
p.write_text(s)

print('generic views finalized')
