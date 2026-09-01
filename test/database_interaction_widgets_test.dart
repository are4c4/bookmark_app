import 'package:bookmark_app/widgets/database_create_tiles.dart';
import 'package:bookmark_app/widgets/detail_property_row.dart';
import 'package:bookmark_app/widgets/resizable_detail_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('property value area invokes the same add action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: DetailPropertyRow(
              icon: Icons.sell_outlined,
              label: 'タグ',
              child: const Text('なし'),
              onAdd: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('なし'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('database create card creates item with Enter', (tester) async {
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: DatabaseCreateCard(
              label: '新しい人物',
              onCreate: (value) async => created = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('新しい人物'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '山口一郎（サカナクション）');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(created, '山口一郎（サカナクション）');
  });

  testWidgets('resizable detail pane reacts to horizontal drag', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: ResizableDetailPane(
              storageKey: 'test-detail-pane',
              initialWidth: 400,
              child: SizedBox.expand(key: ValueKey('detail-content')),
            ),
          ),
        ),
      ),
    );

    final before = tester.getSize(find.byKey(const ValueKey('detail-content'))).width;
    final divider = find.byType(GestureDetector).first;
    await tester.drag(divider, const Offset(-60, 0));
    await tester.pump();
    final after = tester.getSize(find.byKey(const ValueKey('detail-content'))).width;

    expect(after, greaterThan(before));
  });
}
