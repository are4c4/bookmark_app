import 'package:flutter/material.dart';

void showAppToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: actionLabel == null ? (error ? 6 : 3) : 5),
        behavior: SnackBarBehavior.floating,
        width: 440,
        margin: const EdgeInsets.only(right: 16, bottom: 16),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                onPressed: onAction ?? () {},
              ),
      ),
    );
}
