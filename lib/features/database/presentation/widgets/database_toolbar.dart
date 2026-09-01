import 'package:flutter/material.dart';

/// Shared toolbar layout for database-like screens.
///
/// The toolbar keeps view-scoped actions together and intentionally avoids a
/// permanently expanded search field or a three-button layout switcher.
class DatabaseToolbar extends StatefulWidget {
  const DatabaseToolbar({
    super.key,
    required this.leadingActions,
    required this.layoutType,
    required this.supportedLayouts,
    required this.onLayoutChanged,
    required this.searchController,
    required this.onSearchChanged,
    this.trailingActions = const [],
    this.searchHint = '検索',
  });

  final List<Widget> leadingActions;
  final List<Widget> trailingActions;
  final String layoutType;
  final List<String> supportedLayouts;
  final ValueChanged<String> onLayoutChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String searchHint;

  @override
  State<DatabaseToolbar> createState() => _DatabaseToolbarState();
}

class _DatabaseToolbarState extends State<DatabaseToolbar> {
  final _searchFocus = FocusNode();
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchExpanded = widget.searchController.text.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant DatabaseToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchController.text.isNotEmpty && !_searchExpanded) {
      setState(() => _searchExpanded = true);
    }
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  String _layoutLabel(String value) => switch (value) {
        'list' => 'リスト',
        'table' => 'テーブル',
        _ => 'ギャラリー',
      };

  IconData _layoutIcon(String value) => switch (value) {
        'list' => Icons.view_list,
        'table' => Icons.table_rows,
        _ => Icons.grid_view,
      };

  void _openSearch() {
    if (_searchExpanded) return;
    setState(() => _searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    if (widget.searchController.text.isNotEmpty) {
      widget.searchController.clear();
      widget.onSearchChanged('');
    }
    _searchFocus.unfocus();
    setState(() => _searchExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      minHeight: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.leadingActions,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            key: const ValueKey('database-layout-menu'),
            tooltip: '表示形式',
            initialValue: widget.layoutType,
            onSelected: widget.onLayoutChanged,
            itemBuilder: (_) => widget.supportedLayouts
                .map(
                  (layout) => PopupMenuItem<String>(
                    value: layout,
                    child: Row(
                      children: [
                        Icon(_layoutIcon(layout), size: 17),
                        const SizedBox(width: 8),
                        Text(_layoutLabel(layout)),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_layoutIcon(widget.layoutType), size: 17),
                  const SizedBox(width: 6),
                  Text(
                    _layoutLabel(widget.layoutType),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_down, size: 16),
                ],
              ),
            ),
          ),
          ...widget.trailingActions,
          AnimatedSize(
            duration: const Duration(milliseconds: 120),
            alignment: Alignment.centerRight,
            child: _searchExpanded
                ? SizedBox(
                    key: const ValueKey('database-search-expanded'),
                    width: 220,
                    height: 34,
                    child: TextField(
                      controller: widget.searchController,
                      focusNode: _searchFocus,
                      onChanged: widget.onSearchChanged,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search, size: 17),
                        suffixIcon: IconButton(
                          tooltip: '検索を閉じる',
                          visualDensity: VisualDensity.compact,
                          onPressed: _closeSearch,
                          icon: const Icon(Icons.close, size: 15),
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerLow,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('database-search-button'),
                    tooltip: '検索',
                    visualDensity: VisualDensity.compact,
                    onPressed: _openSearch,
                    icon: const Icon(Icons.search, size: 19),
                  ),
          ),
        ],
      ),
    );
  }
}
