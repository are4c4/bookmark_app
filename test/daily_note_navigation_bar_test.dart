import 'package:bookmark_app/features/object/presentation/widgets/daily_note_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required VoidCallback onPrevious,
    required VoidCallback onToday,
    required VoidCallback onNext,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DailyNoteNavigationBar(
          currentDate: DateTime(2026, 9, 3, 23, 59),
          onPrevious: onPrevious,
          onToday: onToday,
          onNext: onNext,
          enabled: enabled,
        ),
      ),
    );
  }

  testWidgets('shows calendar date and dispatches navigation', (tester) async {
    var previous = 0;
    var today = 0;
    var next = 0;
    await tester.pumpWidget(host(
      onPrevious: () => previous++,
      onToday: () => today++,
      onNext: () => next++,
    ));

    expect(find.text('2026-09-03'), findsOneWidget);
    await tester.tap(find.byTooltip('前の日'));
    await tester.tap(find.text('今日'));
    await tester.tap(find.byTooltip('次の日'));
    expect(previous, 1);
    expect(today, 1);
    expect(next, 1);
  });

  testWidgets('disables all navigation while a host is loading', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(
      onPrevious: () => calls++,
      onToday: () => calls++,
      onNext: () => calls++,
      enabled: false,
    ));

    await tester.tap(find.byTooltip('前の日'), warnIfMissed: false);
    await tester.tap(find.text('今日'), warnIfMissed: false);
    await tester.tap(find.byTooltip('次の日'), warnIfMissed: false);
    expect(calls, 0);
  });
}
