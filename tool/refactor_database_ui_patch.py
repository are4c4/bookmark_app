from pathlib import Path
import re

page = Path('lib/views/bookmark_unified_stage1_page.dart')
text = page.read_text()

import_line = "import '../features/database/presentation/widgets/database_toolbar.dart';\n"
marker = "import '../data/workspace_store.dart';\n"
if import_line not in text:
    if marker not in text:
        raise SystemExit('bookmark toolbar import marker not found')
    text = text.replace(marker, marker + import_line, 1)

pattern = re.compile(
    r"  Widget _viewSwitcher\(\) => SegmentedButton<BookmarkStage1ViewType>\(.*?\n  Widget _tagTree",
    re.S,
)
replacement = '''  Widget _toolbar() {
    final filterCount = (_favoritesOnly ? 1 : 0) +
        (_statusFilter.isNotEmpty ? 1 : 0) +
        (_minRating > 0 ? 1 : 0) +
        (_relationFilterLabel == null ? 0 : 1);

    return DatabaseToolbar(
      leadingActions: [
        TextButton.icon(
          onPressed: _showFilterDialog,
          icon: const Icon(Icons.filter_alt_outlined, size: 17),
          label: Text(
            filterCount == 0 ? 'フィルター' : 'フィルター $filterCount',
          ),
        ),
        PopupMenuButton<BookmarkStage1SortField>(
          tooltip: '並べ替え',
          initialValue: _sortField,
          onSelected: (value) => setState(() {
            _sortField = value;
            _markViewChanged();
          }),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: BookmarkStage1SortField.createdAt,
              child: Text('登録日時'),
            ),
            PopupMenuItem(
              value: BookmarkStage1SortField.title,
              child: Text('タイトル'),
            ),
            PopupMenuItem(
              value: BookmarkStage1SortField.url,
              child: Text('URL'),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert, size: 17),
                SizedBox(width: 6),
                Text('並べ替え'),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: _sortAscending ? '昇順' : '降順',
          onPressed: () => setState(() {
            _sortAscending = !_sortAscending;
            _markViewChanged();
          }),
          icon: Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
          ),
        ),
        TextButton.icon(
          onPressed: _showPropertiesDialog,
          icon: const Icon(Icons.tune, size: 17),
          label: const Text('プロパティ'),
        ),
      ],
      trailingActions: [
        PopupMenuButton<String>(
          tooltip: 'その他',
          icon: const Icon(Icons.more_horiz, size: 19),
          onSelected: (value) {
            if (value == 'select') _toggleSelectionMode();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'select',
              child: Row(
                children: [
                  Icon(Icons.check_box_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('複数選択'),
                ],
              ),
            ),
          ],
        ),
      ],
      layoutType: _layoutKey,
      supportedLayouts: const ['gallery', 'table', 'list'],
      onLayoutChanged: (layout) => setState(() {
        _viewType = switch (layout) {
          'list' => BookmarkStage1ViewType.list,
          'table' => BookmarkStage1ViewType.table,
          _ => BookmarkStage1ViewType.gallery,
        };
        _markViewChanged();
      }),
      searchController: _searchController,
      onSearchChanged: (value) => setState(() {
        _query = value;
        _markViewChanged();
      }),
    );
  }

  Widget _tagTree'''
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit(f'bookmark toolbar replacement count={count}')
page.write_text(text)

props = Path('lib/widgets/bookmark_reorderable_properties.dart')
ptext = props.read_text()
old = '''  Widget _dragHandle(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Icon(
          Icons.drag_indicator,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .50),
        ),
      );'''
new = '''  Widget _dragHandle(BuildContext context) => Icon(
        Icons.drag_indicator,
        size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .50),
      );'''
if old not in ptext:
    raise SystemExit('drag handle block not found')
props.write_text(ptext.replace(old, new, 1))
