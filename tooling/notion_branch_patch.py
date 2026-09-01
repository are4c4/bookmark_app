from pathlib import Path

path = Path('lib/views/bookmark_unified_stage1_page.dart')
text = path.read_text()

text = text.replace(
    "import '../widgets/bookmark_detail_panel.dart';\n",
    "import '../widgets/bookmark_detail_panel.dart';\nimport '../widgets/bookmark_list_metadata.dart';\nimport '../widgets/database_create_tiles.dart';\n",
)

text = text.replace(
"""              final details = _orderedListDetails(
                bookmark,
                roleSnapshot.data ?? const [],
              );
""",
"""              final assignments =
                  roleSnapshot.data ?? const <PersonRoleAssignment>[];
""",
)

text = text.replace(
"""                  subtitle: details.isEmpty
                      ? null
                      : Text(
                          details.join('  ·  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
""",
"""                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: BookmarkListMetadata(
                      bookmark: bookmark,
                      assignments: assignments,
                      propertyTokens: _visiblePropertyTokens,
                    ),
                  ),
""",
)

text = text.replace(
"""  Widget _gallery(List<BookmarkItem> bookmarks) => LayoutBuilder(
        builder: (context, constraints) {
""",
"""  Widget _gallery(List<BookmarkItem> bookmarks) => LayoutBuilder(
        builder: (context, constraints) {
""",
)
text = text.replace(
"""            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
""",
"""            itemCount: bookmarks.length + 1,
            itemBuilder: (context, index) {
              if (index == bookmarks.length) {
                return DatabaseActionCard(
                  label: '新しいブックマーク',
                  icon: Icons.add,
                  onPressed: () => showBookmarkCreateDialog(
                    context: context,
                    repository: widget.repository,
                  ),
                );
              }
              final bookmark = bookmarks[index];
""",
1,
)

text = text.replace(
"""  Widget _list(List<BookmarkItem> bookmarks) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
        itemCount: bookmarks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
""",
"""  Widget _list(List<BookmarkItem> bookmarks) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
        itemCount: bookmarks.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == bookmarks.length) {
            return DatabaseActionRow(
              label: '新しいブックマーク',
              icon: Icons.add,
              onPressed: () => showBookmarkCreateDialog(
                context: context,
                repository: widget.repository,
              ),
            );
          }
          final bookmark = bookmarks[index];
""",
)

old_ask = """  Future<String?> _askName(
    String title, {
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    var value = initialValue;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          controller: controller,
          autofocus: true,
          onChanged: (text) => value = text,
          onFieldSubmitted: (_) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
"""
new_ask = """  Future<String?> _askName(
    String title, {
    String initialValue = '',
  }) async {
    var value = initialValue;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          onChanged: (text) => value = text,
          onFieldSubmitted: (_) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
"""
if old_ask not in text:
    raise SystemExit('askName block not found')
text = text.replace(old_ask, new_ask)

text = text.replace(
"""          floatingActionButton: _selectionMode
              ? null
              : FloatingActionButton.extended(
""",
"""          floatingActionButton:
              _selectionMode || _viewType != BookmarkStage1ViewType.table
                  ? null
                  : FloatingActionButton.extended(
""",
)

path.write_text(text)
