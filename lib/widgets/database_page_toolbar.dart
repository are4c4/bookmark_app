import 'package:flutter/material.dart';

import '../ui/ui_tokens.dart';

/// Shared top toolbar used by database-style pages.
///
/// Keeps title, search and view controls aligned across bookmarks, photos and
/// people without forcing each page to duplicate layout constants.
class DatabasePageToolbar extends StatefulWidget {
  const DatabasePageToolbar({
    super.key,
    required this.title,
    required this.searchHint,
    required this.onSearchChanged,
    this.searchValue = '',
    this.leadingActions = const [],
    this.viewSwitcher,
    this.trailingActions = const [],
  });

  final String title;
  final String searchHint;
  final String searchValue;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> leadingActions;
  final Widget? viewSwitcher;
  final List<Widget> trailingActions;

  @override
  State<DatabasePageToolbar> createState() => _DatabasePageToolbarState();
}

class _DatabasePageToolbarState extends State<DatabasePageToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchValue);
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: UiTokens.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: UiTokens.space12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: UiTokens.textLg,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.leadingActions.isNotEmpty) ...[
            const SizedBox(width: UiTokens.space12),
            ...widget.leadingActions,
          ],
          const Spacer(),
          if (widget.viewSwitcher != null) ...[
            widget.viewSwitcher!,
            const SizedBox(width: UiTokens.space12),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  widget.onSearchChanged(value);
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search, size: UiTokens.iconNormal),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '検索をクリア',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            widget.onSearchChanged('');
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UiTokens.radiusSm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (widget.trailingActions.isNotEmpty) ...[
            const SizedBox(width: UiTokens.space8),
            ...widget.trailingActions,
          ],
        ],
      ),
    );
  }
}
