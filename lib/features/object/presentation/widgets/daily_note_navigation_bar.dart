import 'package:flutter/material.dart';

/// Stateless chrome for previous/today/next Daily Note navigation.
///
/// Hosts own async loading through `DailyNoteDetailNavigationService`; this
/// widget only provides one reusable interaction surface for full-page/peek
/// Object detail presentations.
class DailyNoteNavigationBar extends StatelessWidget {
  const DailyNoteNavigationBar({
    super.key,
    required this.currentDate,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
    this.enabled = true,
  });

  final DateTime currentDate;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final localDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final label = '${localDate.year}-${_two(localDate.month)}-${_two(localDate.day)}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '前の日',
          onPressed: enabled ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        TextButton(
          onPressed: enabled ? onToday : null,
          child: const Text('今日'),
        ),
        Semantics(
          label: '現在のDaily Noteの日付',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label),
          ),
        ),
        IconButton(
          tooltip: '次の日',
          onPressed: enabled ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
