import 'package:flutter/material.dart';

import '../../../../ui/ui_tokens.dart';

/// Shared top toolbar for all database-style pages.
///
/// Supports the legacy [viewSwitcher] slot while pages migrate to the common
/// [layoutType] menu. Search is collapsed until requested (or until a saved
/// view restores a non-empty query), keeping view controls visually grouped.
class DatabasePageToolbar extends StatefulWidget {
  const DatabasePageToolbar({
    super.key,
    this.title = '',
    required this.searchHint,
    required this.onSearchChanged,
    this.searchValue = '',
    this.leadingActions = const [],
    this.viewSwitcher,
    this.trailingActions = const [],
    this.layoutType,
    this.supportedLayouts = const ['gallery', 'list', 'table'],
    this.onLayoutChanged,
  });

  final String title;
  final String searchHint;
  final String searchValue;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> leadingActions;
  final Widget? viewSwitcher;
  final List<Widget> trailingActions;
  final String? layoutType;
  final List<String> supportedLayouts;
  final ValueChanged<String>? onLayoutChanged;

  @override
  State<DatabasePageToolbar> createState() => _DatabasePageToolbarState();
}

class _DatabasePageToolbarState extends State<DatabasePageToolbar> {
  late final TextEditingController _searchController;
  final _searchFocus = FocusNode();
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchValue);
    _searchExpanded = widget.searchValue.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant DatabasePageToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchValue != widget.searchValue &&
        _searchController.text != widget.searchValue) {
      _searchController.value = TextEditingValue(
        text: widget.searchValue,
        selection: TextSelection.collapsed(offset: widget.searchValue.length),
      );
    }
    if (widget.searchValue.isNotEmpty && !_searchExpanded) {
      setState(() => _searchExpanded = true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      widget.onSearchChanged('');
    }
    _searchFocus.unfocus();
    setState(() => _searchExpanded = false);
  }

  Widget _layoutControl() {
    final layout = widget.layoutType;
    final onChanged = widget.onLayoutChanged;
    if (layout != null && onChanged != null) {
      return PopupMenuButton<String>(
        key: const ValueKey('database-layout-menu'),
        tooltip: '表示形式',
        initialValue: layout,
        onSelected: onChanged,
        itemBuilder: (_) => widget.supportedLayouts
            .map(
              (value) => PopupMenuItem<String>(
                value: value,
                child: Row(
                  children: [
                    Icon(_layoutIcon(value), size: 17),
                    const SizedBox(width: 8),
                    Text(_layoutLabel(value)),
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
              Icon(_layoutIcon(layout), size: 17),
              const SizedBox(width: 6),
              Text(_layoutLabel(layout), style: const TextStyle(fontSize: 12.5)),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ),
        ),
      );
    }
    return widget.viewSwitcher ?? const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: UiTokens.toolbarHeight),
      padding: const EdgeInsets.symmetric(horizontal: UiTokens.space12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (widget.title.isNotEmpty) ...[
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: UiTokens.textLg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: UiTokens.space12),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.leadingActions,
              ),
            ),
          ),
          const SizedBox(width: UiTokens.space8),
          _layoutControl(),
          if (widget.trailingActions.isNotEmpty) ...[
            const SizedBox(width: UiTokens.space8),
            ...widget.trailingActions,
          ],
          const SizedBox(width: UiTokens.space8),
          AnimatedSize(
            duration: const Duration(milliseconds: 120),
            alignment: Alignment.centerRight,
            child: _searchExpanded
                ? SizedBox(
                    key: const ValueKey('database-search-expanded'),
                    width: 220,
                    height: 36,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: (value) {
                        widget.onSearchChanged(value);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search, size: UiTokens.iconNormal),
                        suffixIcon: IconButton(
                          tooltip: '検索を閉じる',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: _closeSearch,
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UiTokens.radiusSm),
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
                    icon: const Icon(Icons.search, size: UiTokens.iconNormal),
                  ),
          ),
        ],
      ),
    );
  }
}
