import 'package:flutter/material.dart';

void showAppToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(message)),
            if (actionLabel != null) ...[
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onAction?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: scheme.inversePrimary,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
        duration: Duration(seconds: actionLabel == null ? (error ? 6 : 3) : 5),
        behavior: SnackBarBehavior.floating,
        width: 440,
        margin: const EdgeInsets.only(right: 16, bottom: 16),
      ),
    );
}
