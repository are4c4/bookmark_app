from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'anchor not found: {label}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Bookmarks: replace the secondary sidebar with user-defined database views.
# ---------------------------------------------------------------------------
p = Path('lib/views/bookmark_unified_stage1_page.dart')
s = p.read_text()
s = replace_once(
    s,
    "import '../data/bookmark_repository.dart';\n",
    "import '../data/bookmark_repository.dart';\nimport '../data/database_view_store.dart';\nimport '../database/database_definition.dart';\n",
    'bookmark imports data',
)
s = replace_once(
    s,
    "import '../widgets/database_create_tiles.dart';\n",
    "import '../widgets/database_create_tiles.dart';\nimport '../widgets/database_view_tabs.dart';\n",
    'bookmark imports tabs',
)
s = replace_once(
    s,
    "  Timer? _savedViewSaveTimer;\n",
    "  Timer? _savedViewSaveTimer;\n  Timer? _databaseViewSaveTimer;\n  late final DatabaseViewStore _databaseViewStore;\n  int? _activeDatabaseViewId;\n  DatabaseViewConfig? _activeDatabaseView;\n",
    'bookmark fields',
)
s = replace_once(
    s,
    "  @override\n  void dispose() {\n    _savedViewSaveTimer?.cancel();\n",
    "  @override\n  void initState() {\n    super.initState();\n    _databaseViewStore = DatabaseViewStore(widget.repository.workspaceStore.database);\n  }\n\n  @override\n  void dispose() {\n    _savedViewSaveTimer?.cancel();\n    _databaseViewSaveTimer?.cancel();\n",
    'bookmark init dispose',
)
old_mark = """  void _markViewChanged() {
    final id = _activeSavedViewId;
    if (id == null) return;
    _savedViewSaveTimer?.cancel();
    _savedViewSaveTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted && _activeSavedViewId == id) _updateActiveView();
    });
  }
"""
new_mark = """  void _applyDatabaseView(DatabaseViewConfig view) {
    final filters = view.filters;
    final sort = view.sorts.whereType<Map>().firstOrNull;
    final tokens = view.visibleProperties.isEmpty
        ? BuiltInDatabases.bookmarks.defaultVisibleProperties
        : view.visibleProperties;
    final base = <BookmarkStage1Property>{};
    final roles = <String>{};
    for (final key in tokens) {
      if (key.startsWith('role:')) {
        roles.add(key.substring(5));
      } else {
        final property = bookmarkPropertyFromKey(key);
        if (property != null) base.add(property);
      }
    }
    final query = (filters['query'] as String?) ?? '';
    final rawTagIds = filters['tagIds'];
    final tagIds = rawTagIds is List
        ? rawTagIds.whereType<num>().map((value) => value.toInt()).toSet()
        : <int>{};
    final width = view.settings['detailWidth'];
    _searchController.text = query;
    setState(() {
      _query = query;
      _favoritesOnly = filters['favoritesOnly'] == true;
      _statusFilter = (filters['status'] as String?) ?? '';
      _minRating = (filters['minRating'] as num?)?.toInt() ?? 0;
      _tagMatchMode = (filters['tagMatchMode'] as String?) ?? 'or';
      _includeDescendants = filters['includeDescendants'] != false;
      _personFilterId = (filters['personId'] as num?)?.toInt();
      _photoFilterId = (filters['photoId'] as num?)?.toInt();
      _selectedTagIds
        ..clear()
        ..addAll(tagIds);
      _viewType = switch (view.layoutType) {
        'list' => BookmarkStage1ViewType.list,
        'table' => BookmarkStage1ViewType.table,
        _ => BookmarkStage1ViewType.gallery,
      };
      final sortField = sort?['field'] as String?;
      _sortField = switch (sortField) {
        'title' => BookmarkStage1SortField.title,
        'url' => BookmarkStage1SortField.url,
        _ => BookmarkStage1SortField.createdAt,
      };
      _sortAscending = sort?['direction'] == 'asc';
      _propertyOrder = normalizeBookmarkPropertyOrder(
        view.propertyOrder.isEmpty ? tokens : view.propertyOrder,
      );
      _visibleProperties
        ..clear()
        ..addAll(base);
      _visiblePersonRoles
        ..clear()
        ..addAll(roles);
      if (width is num) _detailWidth = width.toDouble().clamp(320.0, 720.0);
      _activeDatabaseViewId = view.id;
      _activeDatabaseView = view;
      _activeSavedViewId = null;
      _relationFilterLabel = null;
    });
  }

  void _scheduleDatabaseViewSave() {
    final active = _activeDatabaseView;
    if (active == null) return;
    _databaseViewSaveTimer?.cancel();
    _databaseViewSaveTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted && _activeDatabaseViewId == active.id) {
        _saveActiveDatabaseView();
      }
    });
  }

  Future<void> _saveActiveDatabaseView() async {
    final active = _activeDatabaseView;
    if (active == null) return;
    final next = active.copyWith(
      layoutType: _layoutKey,
      filters: {
        'query': _query,
        'favoritesOnly': _favoritesOnly,
        'tagIds': _selectedTagIds.toList(),
        'tagMatchMode': _tagMatchMode,
        'includeDescendants': _includeDescendants,
        'status': _statusFilter,
        'minRating': _minRating,
        'personId': _personFilterId,
        'photoId': _photoFilterId,
      },
      sorts: [
        {'field': _sortKey, 'direction': _sortAscending ? 'asc' : 'desc'},
      ],
      visibleProperties: _visiblePropertyTokens,
      propertyOrder: _propertyOrder,
      settings: {...active.settings, 'detailWidth': _detailWidth},
    );
    await _databaseViewStore.updateView(next);
    if (mounted && _activeDatabaseViewId == active.id) {
      _activeDatabaseView = next;
    }
  }

  Widget _databaseViewTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 10, 0),
        child: DatabaseViewTabs(
          store: _databaseViewStore,
          definition: BuiltInDatabases.bookmarks,
          workspaceId: widget.repository.workspaceId,
          activeViewId: _activeDatabaseViewId,
          onSelected: _applyDatabaseView,
        ),
      );

  void _markViewChanged() {
    _scheduleDatabaseViewSave();
    final id = _activeSavedViewId;
    if (id == null) return;
    _savedViewSaveTimer?.cancel();
    _savedViewSaveTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted && _activeSavedViewId == id) _updateActiveView();
    });
  }
"""
s = replace_once(s, old_mark, new_mark, 'bookmark generic view methods')

s = replace_once(
    s,
    """  Future<void> _showFilterDialog() async {
    var favorites = _favoritesOnly;
    var status = _statusFilter;
    var minRating = _minRating;
    var tagMatchMode = _tagMatchMode;
    var includeDescendants = _includeDescendants;
    await showDialog<void>(
""",
    """  Future<void> _showFilterDialog() async {
    final allTags = await widget.repository.watchTags().first;
    if (!mounted) return;
    var favorites = _favoritesOnly;
    var status = _statusFilter;
    var minRating = _minRating;
    var tagMatchMode = _tagMatchMode;
    var includeDescendants = _includeDescendants;
    var selectedTagIds = {..._selectedTagIds};
    await showDialog<void>(
""",
    'bookmark filter vars',
)
s = replace_once(
    s,
    """            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
""",
    """            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sell_outlined, size: 19),
                title: const Text('タグ'),
                subtitle: Text(
                  selectedTagIds.isEmpty
                      ? 'すべて'
                      : allTags
                          .where((tag) => selectedTagIds.contains(tag.id))
                          .map((tag) => tag.name)
                          .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final selected = await showTagDatabasePicker(
                    context: dialogContext,
                    tags: allTags,
                    initiallySelectedIds: selectedTagIds,
                    onCreateTag: _createTagFromPicker,
                  );
                  if (selected != null && dialogContext.mounted) {
                    setLocalState(() {
                      selectedTagIds = selected.map((tag) => tag.id).toSet();
                    });
                  }
                },
              ),
              SwitchListTile(
""",
    'bookmark filter tag picker',
)
s = replace_once(
    s,
    """                  _tagMatchMode = tagMatchMode;
                  _includeDescendants = includeDescendants;
                  _markViewChanged();
""",
    """                  _tagMatchMode = tagMatchMode;
                  _includeDescendants = includeDescendants;
                  _selectedTagIds
                    ..clear()
                    ..addAll(selectedTagIds);
                  _markViewChanged();
""",
    'bookmark filter apply tags',
)
s = replace_once(
    s,
    """                  final showSidebar = constraints.maxWidth >= 520 &&
                      (!wantsDetail || constraints.maxWidth >= 900);
""",
    """                  // Database navigation now lives in the Notion-style
                  // view tabs above the toolbar, avoiding a second sidebar.
                  const showSidebar = false;
""",
    'bookmark hide secondary sidebar',
)
s = replace_once(
    s,
    """                        child: Column(children: [
                          _toolbar(),
""",
    """                        child: Column(children: [
                          _databaseViewTabs(),
                          _toolbar(),
""",
    'bookmark insert tabs',
)
p.write_text(s)


# ---------------------------------------------------------------------------
# People: same reusable view model and tabs.
# ---------------------------------------------------------------------------
p = Path('lib/views/people_management_page.dart')
s = p.read_text()
s = replace_once(s, "import 'dart:io';\n", "import 'dart:async';\nimport 'dart:io';\n", 'people async import')
s = replace_once(
    s,
    "import '../data/bookmark_repository.dart';\n",
    "import '../data/bookmark_repository.dart';\nimport '../data/database_view_store.dart';\nimport '../database/database_definition.dart';\n",
    'people generic imports',
)
s = replace_once(
    s,
    "import '../widgets/database_page_toolbar.dart';\n",
    "import '../widgets/database_page_toolbar.dart';\nimport '../widgets/database_view_tabs.dart';\n",
    'people tabs import',
)
s = replace_once(
    s,
    """  int? _selectedGroupId;
  late final PersonGroupStore _personGroups;
""",
    """  int? _selectedGroupId;
  late final PersonGroupStore _personGroups;
  late final DatabaseViewStore _databaseViewStore;
  DatabaseViewConfig? _activeDatabaseView;
  int? _activeDatabaseViewId;
  Timer? _viewSaveTimer;
""",
    'people fields',
)
s = replace_once(
    s,
    """    _personGroups = PersonGroupStore(repository.workspaceStore.database);
  }
""",
    """    _personGroups = PersonGroupStore(repository.workspaceStore.database);
    _databaseViewStore = DatabaseViewStore(repository.workspaceStore.database);
  }

  @override
  void dispose() {
    _viewSaveTimer?.cancel();
    super.dispose();
  }

  void _applyDatabaseView(DatabaseViewConfig view) {
    final filters = view.filters;
    setState(() {
      _activeDatabaseView = view;
      _activeDatabaseViewId = view.id;
      _query = (filters['query'] as String?) ?? '';
      _selectedGroupId = (filters['groupId'] as num?)?.toInt();
      _viewType = switch (view.layoutType) {
        'list' => PeopleViewType.list,
        'table' => PeopleViewType.table,
        _ => PeopleViewType.gallery,
      };
    });
  }

  void _markDatabaseViewChanged() {
    final active = _activeDatabaseView;
    if (active == null) return;
    _viewSaveTimer?.cancel();
    _viewSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _activeDatabaseViewId != active.id) return;
      final next = active.copyWith(
        layoutType: switch (_viewType) {
          PeopleViewType.list => 'list',
          PeopleViewType.table => 'table',
          _ => 'gallery',
        },
        filters: {'query': _query, 'groupId': _selectedGroupId},
      );
      await _databaseViewStore.updateView(next);
      if (mounted && _activeDatabaseViewId == active.id) _activeDatabaseView = next;
    });
  }

  Widget _databaseViewTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 10, 0),
        child: DatabaseViewTabs(
          store: _databaseViewStore,
          definition: BuiltInDatabases.people,
          workspaceId: repository.workspaceId,
          activeViewId: _activeDatabaseViewId,
          onSelected: _applyDatabaseView,
        ),
      );
""",
    'people init generic methods',
)
s = replace_once(
    s,
    """        onSelectionChanged: (value) =>
            setState(() => _viewType = value.first),
""",
    """        onSelectionChanged: (value) => setState(() {
          _viewType = value.first;
          _markDatabaseViewChanged();
        }),
""",
    'people view switch save',
)
s = replace_once(
    s,
    """              setState(() => _selectedGroupId = id < 0 ? null : id);
""",
    """              setState(() {
                _selectedGroupId = id < 0 ? null : id;
                _markDatabaseViewChanged();
              });
""",
    'people group save',
)
s = replace_once(
    s,
    """        children: [
          DatabasePageToolbar(
            title: '人物',
            searchHint: '人物を検索',
            onSearchChanged: (value) => setState(() => _query = value),
""",
    """        children: [
          _databaseViewTabs(),
          DatabasePageToolbar(
            title: '人物',
            searchHint: '人物を検索',
            onSearchChanged: (value) => setState(() {
              _query = value;
              _markDatabaseViewChanged();
            }),
""",
    'people build tabs search',
)
p.write_text(s)


# ---------------------------------------------------------------------------
# Photos: same view tabs and per-view search/layout persistence.
# ---------------------------------------------------------------------------
p = Path('lib/views/photo_management_page.dart')
s = p.read_text()
s = replace_once(s, "import 'dart:io';\n", "import 'dart:async';\nimport 'dart:io';\n", 'photo async import')
s = replace_once(
    s,
    "import '../data/bookmark_repository.dart';\n",
    "import '../data/bookmark_repository.dart';\nimport '../data/database_view_store.dart';\nimport '../database/database_definition.dart';\n",
    'photo generic imports',
)
s = replace_once(
    s,
    "import '../widgets/database_page_toolbar.dart';\n",
    "import '../widgets/database_page_toolbar.dart';\nimport '../widgets/database_view_tabs.dart';\n",
    'photo tabs import',
)
s = replace_once(
    s,
    """  int? _selectedPhotoId;
  String _query = '';

  BookmarkRepository get repository => widget.repository;
""",
    """  int? _selectedPhotoId;
  String _query = '';
  late final DatabaseViewStore _databaseViewStore;
  DatabaseViewConfig? _activeDatabaseView;
  int? _activeDatabaseViewId;
  Timer? _viewSaveTimer;

  BookmarkRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _databaseViewStore = DatabaseViewStore(repository.workspaceStore.database);
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
      _viewType = switch (view.layoutType) {
        'list' => PhotoViewType.list,
        'table' => PhotoViewType.table,
        _ => PhotoViewType.gallery,
      };
    });
  }

  void _markDatabaseViewChanged() {
    final active = _activeDatabaseView;
    if (active == null) return;
    _viewSaveTimer?.cancel();
    _viewSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _activeDatabaseViewId != active.id) return;
      final next = active.copyWith(
        layoutType: switch (_viewType) {
          PhotoViewType.list => 'list',
          PhotoViewType.table => 'table',
          _ => 'gallery',
        },
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
          definition: BuiltInDatabases.photos,
          workspaceId: repository.workspaceId,
          activeViewId: _activeDatabaseViewId,
          onSelected: _applyDatabaseView,
        ),
      );
""",
    'photo generic state',
)
s = replace_once(
    s,
    """        onSelectionChanged: (value) =>
            setState(() => _viewType = value.first),
""",
    """        onSelectionChanged: (value) => setState(() {
          _viewType = value.first;
          _markDatabaseViewChanged();
        }),
""",
    'photo view switch save',
)
s = replace_once(
    s,
    """        children: [
          DatabasePageToolbar(
            title: '写真',
            searchHint: '写真を検索',
            onSearchChanged: (value) => setState(() => _query = value),
""",
    """        children: [
          _databaseViewTabs(),
          DatabasePageToolbar(
            title: '写真',
            searchHint: '写真を検索',
            onSearchChanged: (value) => setState(() {
              _query = value;
              _markDatabaseViewChanged();
            }),
""",
    'photo build tabs search',
)
p.write_text(s)


# ---------------------------------------------------------------------------
# App shell: simplify Library navigation. Inbox/archive become ordinary views.
# ---------------------------------------------------------------------------
p = Path('lib/views/app_shell.dart')
s = p.read_text()
s = replace_once(
    s,
    """              _sectionHeader('LIBRARY'),
              _navTile(0, Icons.bookmarks_outlined, 'ブックマーク'),
              _subNavTile(2, Icons.inbox_outlined, '未整理'),
              _subNavTile(3, Icons.archive_outlined, 'アーカイブ'),
              _subNavTile(4, Icons.delete_outline, 'ゴミ箱'),
              const SizedBox(height: UiTokens.space4),
              _navTile(1, Icons.search, '全文検索'),
              const Padding(padding: EdgeInsets.symmetric(horizontal: UiTokens.space12, vertical: UiTokens.space6), child: Divider(height: 1)),
              _navTile(5, Icons.photo_library_outlined, '写真'),
              _navTile(6, Icons.account_tree_outlined, 'タグ'),
              _navTile(7, Icons.people_outline, '人物'),
              _navTile(8, Icons.collections_bookmark_outlined, 'コレクション'),
              _navTile(9, Icons.manage_accounts_outlined, 'Profile管理'),
              _navTile(10, Icons.settings_outlined, '設定'),
""",
    """              _sectionHeader('DATABASES'),
              _navTile(0, Icons.bookmarks_outlined, 'ブックマーク'),
              _navTile(5, Icons.photo_library_outlined, '写真'),
              _navTile(7, Icons.people_outline, '人物'),
              _navTile(6, Icons.account_tree_outlined, 'タグ'),
              _navTile(8, Icons.collections_bookmark_outlined, 'コレクション'),
              const SizedBox(height: UiTokens.space6),
              _navTile(1, Icons.search, '全文検索'),
              const Padding(padding: EdgeInsets.symmetric(horizontal: UiTokens.space12, vertical: UiTokens.space6), child: Divider(height: 1)),
              _sectionHeader('管理'),
              _navTile(4, Icons.delete_outline, 'ゴミ箱'),
              _navTile(9, Icons.manage_accounts_outlined, 'Profile管理'),
              _navTile(10, Icons.settings_outlined, '設定'),
""",
    'shell simplified expanded nav',
)
old_collapsed = """    final icons = [
      Icons.bookmarks_outlined,
      Icons.search,
      Icons.inbox_outlined,
      Icons.archive_outlined,
      Icons.delete_outline,
      Icons.photo_library_outlined,
      Icons.account_tree_outlined,
      Icons.people_outline,
      Icons.collections_bookmark_outlined,
      Icons.manage_accounts_outlined,
      Icons.settings_outlined,
    ];
"""
new_collapsed = """    const destinations = <(int, IconData)>[
      (0, Icons.bookmarks_outlined),
      (5, Icons.photo_library_outlined),
      (7, Icons.people_outline),
      (6, Icons.account_tree_outlined),
      (8, Icons.collections_bookmark_outlined),
      (1, Icons.search),
      (4, Icons.delete_outline),
      (9, Icons.manage_accounts_outlined),
      (10, Icons.settings_outlined),
    ];
"""
s = replace_once(s, old_collapsed, new_collapsed, 'shell collapsed destinations')
s = replace_once(
    s,
    """          ...icons.asMap().entries.map((entry) => IconButton(
            onPressed: () => setState(() => _index = entry.key),
            style: IconButton.styleFrom(backgroundColor: _index == entry.key ? scheme.surfaceContainerHigh : Colors.transparent),
            icon: Icon(entry.value, size: 19),
          )),
""",
    """          ...destinations.map((entry) => IconButton(
            onPressed: () => setState(() => _index = entry.$1),
            style: IconButton.styleFrom(backgroundColor: _index == entry.$1 ? scheme.surfaceContainerHigh : Colors.transparent),
            icon: Icon(entry.$2, size: 19),
          )),
""",
    'shell collapsed map',
)
s = replace_once(
    s,
    """      ('ブックマーク', Icons.bookmarks_outlined, 0),
      ('全文検索', Icons.search, 1),
      ('未整理', Icons.inbox_outlined, 2),
      ('アーカイブ', Icons.archive_outlined, 3),
      ('ゴミ箱', Icons.delete_outline, 4),
      ('写真', Icons.photo_library_outlined, 5),
      ('タグ', Icons.account_tree_outlined, 6),
      ('人物', Icons.people_outline, 7),
      ('コレクション', Icons.collections_bookmark_outlined, 8),
""",
    """      ('ブックマーク', Icons.bookmarks_outlined, 0),
      ('写真', Icons.photo_library_outlined, 5),
      ('人物', Icons.people_outline, 7),
      ('タグ', Icons.account_tree_outlined, 6),
      ('コレクション', Icons.collections_bookmark_outlined, 8),
      ('全文検索', Icons.search, 1),
      ('ゴミ箱', Icons.delete_outline, 4),
""",
    'shell command palette simplified',
)
p.write_text(s)

print('generic database view patch applied')
