import 'package:bookmark_app/widgets/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppEmptyState renders title and action', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.bookmark_outline,
            title: 'ブックマークがありません',
            message: '最初のブックマークを追加してください。',
            actionLabel: '追加',
            onAction: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('ブックマークがありません'), findsOneWidget);
    expect(find.text('最初のブックマークを追加してください。'), findsOneWidget);
    expect(find.text('追加'), findsOneWidget);

    await tester.tap(find.text('追加'));
    expect(pressed, isTrue);
  });
}
