import 'package:flutter/material.dart';

import '../ui/ui_tokens.dart';

/// A lightweight section container for right-side detail panes.
/// It deliberately uses dividers instead of cards so the detail pane keeps a
/// Notion-like flat hierarchy while still making groups easy to scan.
class DetailSection extends StatelessWidget {
  const DetailSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.topDivider = true,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final bool topDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topDivider) Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: UiTokens.space16),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: UiTokens.iconNormal, color: scheme.onSurfaceVariant),
              const SizedBox(width: UiTokens.space8),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: UiTokens.space12),
        child,
        const SizedBox(height: UiTokens.space16),
      ],
    );
  }
}
