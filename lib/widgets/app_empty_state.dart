import 'package:flutter/material.dart';

import '../ui/ui_tokens.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(UiTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: scheme.onSurfaceVariant),
              const SizedBox(height: UiTokens.space12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (message?.trim().isNotEmpty == true) ...[
                const SizedBox(height: UiTokens.space6),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: UiTokens.textSm,
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: UiTokens.space16),
                FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add, size: UiTokens.iconSmall),
                  label: Text(actionLabel!),
                ),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: UiTokens.space6),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
