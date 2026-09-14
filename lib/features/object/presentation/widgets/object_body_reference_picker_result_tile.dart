import 'package:flutter/material.dart';

/// Shared candidate-row presentation for Object Body reference pickers.
///
/// Candidate identity, filtering, and selection semantics remain owned by each
/// picker host. This widget only standardizes the repeated row chrome.
class ObjectBodyReferencePickerResultTile extends StatelessWidget {
  const ObjectBodyReferencePickerResultTile({
    super.key,
    required this.leadingText,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String leadingText;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(leadingText),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
