import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact relation dialog action row lays out safely', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Relation'),
                  content: const Text('Content'),
                  actions: const [
                    TextButton(onPressed: null, child: Text('クリア')),
                    Spacer(),
                    TextButton(onPressed: null, child: Text('キャンセル')),
                    TextButton(onPressed: null, child: Text('保存')),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Relation'), findsOneWidget);
  });
}
