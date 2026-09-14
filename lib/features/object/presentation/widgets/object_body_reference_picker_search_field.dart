import 'package:flutter/material.dart';

/// Shared search-field presentation for Object Body reference pickers.
///
/// Filtering and selection semantics remain owned by each picker host; this
/// widget only standardizes the repeated autofocus/search-icon field chrome.
class ObjectBodyReferencePickerSearchField extends StatelessWidget {
  const ObjectBodyReferencePickerSearchField({
    super.key,
    required this.fieldKey,
    required this.hintText,
    required this.onChanged,
  });

  final Key fieldKey;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      autofocus: true,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hintText,
      ),
      onChanged: onChanged,
    );
  }
}
