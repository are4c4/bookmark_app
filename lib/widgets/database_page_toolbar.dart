import 'package:flutter/material.dart';

import '../ui/ui_tokens.dart';

/// Shared top toolbar used by database-style pages.
///
/// Keeps title, search and view controls aligned across bookmarks, photos and
/// people without forcing each page to duplicate layout constants.
class DatabasePageToolbar extends StatelessWidget {
  const DatabasePageToolbar({
    super.key,
    required this.title,
    required this.searchHint,
    required this.onSearchChanged,
    this.leadingActions = const [],
    this.viewSwitcher,
    this.trailingActions = const [],
  });

  final String title;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> leadingActions;
  final Widget? viewSwitcher;
  final List<Widget> trailingActions;

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
            title,
            style: const TextStyle(
              fontSize: UiTokens.textLg,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (leadingActions.isNotEmpty) ...[
            const SizedBox(width: UiTokens.space12),
            ...leadingActions,
          ],
          const Spacer(),
          if (viewSwitcher != null) ...[
            viewSwitcher!,
            const SizedBox(width: UiTokens.space12),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
            child: SizedBox(
              height: 36,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search, size: UiTokens.iconNormal),
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
          if (trailingActions.isNotEmpty) ...[
            const SizedBox(width: UiTokens.space8),
            ...trailingActions,
          ],
        ],
      ),
    );
  }
}
