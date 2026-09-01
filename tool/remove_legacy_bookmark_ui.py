from pathlib import Path
import re

path = Path('lib/views/bookmark_unified_stage1_page.dart')
text = path.read_text()

# Fields that only served the disabled legacy bookmark sidebar / SavedView UI.
text = text.replace('  bool _sidebarCollapsed = false;\n', '')
text = text.replace('  int? _activeSavedViewId;\n', '')
text = text.replace('  Timer? _savedViewSaveTimer;\n', '')
text = text.replace('  bool get _legacyBookmarkSidebarEnabled => false;\n\n', '')
text = text.replace('    _savedViewSaveTimer?.cancel();\n', '')
text = text.replace('      _activeSavedViewId = null;\n', '')

# Tag-tree helper existed only for the disabled second sidebar.
text = re.sub(
    r"\n  List<Tag> _childrenOf\(int\? parentId, List<Tag> tags\) \{.*?\n  \}\n\n  List<BookmarkItem> _applyFilters",
    "\n  List<BookmarkItem> _applyFilters",
    text,
    count=1,
    flags=re.S,
)

# View changes now only persist to the common DatabaseView model.
text = re.sub(
    r"  void _markViewChanged\(\) \{.*?\n  \}\n\n  void _resetFilters",
    "  void _markViewChanged() => _scheduleDatabaseViewSave();\n\n  void _resetFilters",
    text,
    count=1,
    flags=re.S,
)

# Remove legacy name dialog while preserving _layoutKey / _sortKey.
text = re.sub(
    r"\n  Future<String\?> _askName\(.*?\n  String get _layoutKey",
    "\n  String get _layoutKey",
    text,
    count=1,
    flags=re.S,
)

# Remove legacy SavedView CRUD/apply methods. Common DatabaseView is authoritative.
text = re.sub(
    r"\n  Future<void> _saveCurrentView\(\) async \{.*?\n  Future<Tag\?> _createTagFromPicker",
    "\n  Future<Tag?> _createTagFromPicker",
    text,
    count=1,
    flags=re.S,
)

# Remove old tag-tree + saved-view + second-sidebar rendering block.
text = re.sub(
    r"\n  Widget _tagTree\(List<Tag> allTags, int\? parentId, int depth\) \{.*?\n  String\? _extractUrl",
    "\n  String? _extractUrl",
    text,
    count=1,
    flags=re.S,
)

# The layout no longer reserves or renders the disabled second sidebar.
text = text.replace(
    "                  // Database navigation now lives in the Notion-style\n"
    "                  // view tabs above the toolbar, avoiding a second sidebar.\n"
    "                  final showSidebar = _legacyBookmarkSidebarEnabled;\n"
    "                  final fixedSidebarWidth = showSidebar\n"
    "                      ? (_sidebarCollapsed ? 43.0 : 221.0)\n"
    "                      : 0.0;\n"
    "                  final availableForDetail =\n"
    "                      constraints.maxWidth - fixedSidebarWidth - 260;",
    "                  final availableForDetail = constraints.maxWidth - 260;",
)
text = re.sub(
    r"\n                      if \(showSidebar\) \.\.\.\[.*?\n                      \],\n                      Expanded\(",
    "\n                      Expanded(",
    text,
    count=1,
    flags=re.S,
)

path.write_text(text)
